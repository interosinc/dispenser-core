{-# LANGUAGE FlexibleContexts              #-}
{-# LANGUAGE FlexibleInstances             #-}
{-# LANGUAGE FunctionalDependencies        #-}
{-# LANGUAGE InstanceSigs                  #-}
{-# LANGUAGE LambdaCase                    #-}
{-# LANGUAGE MonoLocalBinds                #-}
{-# LANGUAGE NoImplicitPrelude             #-}
{-# LANGUAGE OverloadedStrings             #-}
{-# LANGUAGE TemplateHaskell               #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module Dispenser.Client.Memory where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import qualified Data.Map                    as Map
import           Dispenser.Functions                       ( genericFromNow
                                                           , initialEventNumber
                                                           , now
                                                           )
import           Dispenser.Types                    hiding ( partitionName )
import           Streaming

newtype MemClient a = MemClient
  { _memClientPartitions :: TVar (Map PartitionName [Event a])
  }

data MemConnection a = MemConnection
  { _memConnectionClient        :: MemClient a
  , _memConnectionPartitionName :: PartitionName
  }

makeFields ''MemClient
makeFields ''MemConnection

new :: IO (MemClient a)
new = MemClient <$> newTVarIO Map.empty

_proof :: PartitionConnection m MemConnection e => Proxy (m e)
_proof = Proxy

instance CanCurrentEventNumber m MemConnection e where
  currentEventNumber conn = fromMaybe (pred initialEventNumber)
    . join . fmap (fmap (view eventNumber) . head) . Map.lookup (conn ^. partitionName)
    <$> (liftIO . atomically . readTVar $ conn ^. (client . partitions))

instance CanFromNow m MemConnection e where
  fromNow = genericFromNow

instance CanFromEventNumber m MemConnection e where
  fromEventNumber conn _batchSize = continueFrom conn

-- TODO: Streams are already monads so these can be written just in terms of
-- the stream instead of an m of the stream.
--
-- TODO: actually filter by streamNames
continueFrom :: MonadIO m
             => MemConnection a
             -> StreamSource
             -> EventNumber
             -> m (Stream (Of (Event a)) m r)
continueFrom conn source minE = do
  debug $ "continueFrom " <> show minE
  events' <- liftIO $ findOrCreateCurrentPartition conn
  -- TODO: non-sleep based solution
  case elligible events' of
    []    -> do
      debug $ "no elligible events -- sleep 0.25 and continue from " <> show minE
      sleep 0.25 >> continueFrom conn source minE
    (e:_) -> do
      debug $ "elligible event " <> show (e ^. eventNumber)
      debug $ "continuing from " <> show (succ $ e ^. eventNumber)
      debug $ "S.cons " <> show (e ^. eventNumber)

      return $ S.yield e >> (join . lift . continueFrom conn source
                               $ succ (e ^. eventNumber))
  where
    elligible = filter matchesStreams . dropWhile ((< minE) . view eventNumber)

    matchesStreams :: Event a -> Bool
    matchesStreams _ = True  -- TODO

instance (EventData e, MonadResource m) => Client (MemClient e) m MemConnection e where
  connect partName client' = return $ MemConnection client' partName

instance (EventData e, MonadResource m) => CanAppendEvents m MemConnection e where
  appendEvents conn streamNames batch = liftIO now >>= doAppend
    where
      doAppend ts = do
        debug $ "doAppend ts=" <> show ts
        liftIO $
          (modifyPartition conn f >> (head <$> findOrCreateCurrentPartition conn)) >>= \case
            Just e  -> return $ e ^. eventNumber
            Nothing -> panic "full list empty after appending from a NonEmpty list."
        where
          f es = (reverse . zipWith toEvent [en..] . toList $ batch) ++ es
            where
              en = maybe initialEventNumber (succ . view eventNumber) . head $ es

          toEvent en payload = Event en streamNames payload ts

instance EventData e => CanRangeStream m MemConnection e where
  rangeStream conn _batchSize _streamNames (minE, maxE) = do
    debug $ "rangeStream " <> show (minE, maxE)
    part <- liftIO $ findOrCreateCurrentPartition conn
    debug $ "part: " <> show part
    S.each
      . takeWhile ((>= minE) . view eventNumber)
      . dropWhile ((> maxE)  . view eventNumber)
      <$> liftIO (findOrCreateCurrentPartition conn)

findOrCreateCurrentPartition :: MemConnection a -> IO [Event a]
findOrCreateCurrentPartition conn = reverse . fromMaybe []
  . Map.lookup (conn ^. partitionName)
  <$> (atomically . readTVar $ conn ^. (client . partitions))

modifyPartition :: MemConnection a ->  ([Event a] -> [Event a]) -> IO ()
modifyPartition conn f = atomically . modifyTVar (conn ^. (client . partitions))
  $ Map.alter (Just . f . fromMaybe []) (conn ^. partitionName)
