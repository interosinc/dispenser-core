{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE InstanceSigs           #-}
{-# LANGUAGE LambdaCase             #-}
{-# LANGUAGE NoImplicitPrelude      #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE TemplateHaskell        #-}

module Dispenser.Client.Memory where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import qualified Data.Map                    as Map
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

instance EventData e => PartitionConnection MemConnection e

instance CanCurrentEventNumber MemConnection e where
  currentEventNumber conn = fromMaybe (pred initialEventNumber)
    . join . fmap (fmap (view eventNumber) . head) . Map.lookup (conn ^. partitionName)
    <$> (liftIO . atomically . readTVar $ conn ^. (client . partitions))

-- TODO: put streamNames back
instance CanFromNow MemConnection e where
  fromNow = genericFromNow

instance CanFromEventNumber MemConnection e where
  fromEventNumber :: (EventData e, MonadResource m)
                  => MemConnection e -> BatchSize -> EventNumber
                  -> m (Stream (Of (Event e)) m r)
  fromEventNumber conn batchSize minE = do
  -- TODO: put streamNames back
    debug $ "MemConnection.fromEventNumber " <> show minE
    events' <- liftIO $ findOrCreateCurrentPartition conn
    -- TODO: non-sleep based solution
    case elligible events' of
      []    -> do
        debug $ "no elligible events -- sleep 0.25"
        sleep 0.25 >> fromEventNumber conn batchSize minE
      es@(e:_) -> case lastMay es of
        Nothing -> panic "unpossible!" -- TODO
        Just le -> do
          debug $ "first elligible event " <> show (e ^. eventNumber)
          debug $ "last elligible event " <> show (le ^. eventNumber)
          debug $ "S.cons through " <> show (le ^. eventNumber)
          debug $ "continuing from " <> show (succ $ le ^. eventNumber)
          return $ S.each es
            >>= (const . join . lift . fromEventNumber conn batchSize $
                   succ (le ^. eventNumber))
    where
      elligible = -- filter (matchesStreams streamNames) .
        dropWhile ((< minE) . view eventNumber)

      -- matchesStreams :: [StreamName] -> Event a -> Bool
      -- matchesStreams _ _ = True  -- TODO

instance EventData e => Client (MemClient e) MemConnection e where
  connect partName client' = return $ MemConnection client' partName

instance EventData e => CanAppendEvents MemConnection e where
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

instance EventData e => CanRangeStream MemConnection e where
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
