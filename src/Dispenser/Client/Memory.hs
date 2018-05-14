{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE InstanceSigs           #-}
{-# LANGUAGE LambdaCase             #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE NoImplicitPrelude      #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TemplateHaskell        #-}

module Dispenser.Client.Memory where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import qualified Data.Map                    as Map
import qualified Dispenser.Catchup           as Catchup
import           Dispenser.Types                        hiding ( partitionName )
import           Streaming

data MemClient a = MemClient
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

instance EventData a => Client (MemClient a) MemConnection a where
  connect partName client' = return $ MemConnection client' partName

instance forall a. EventData a => PartitionConnection MemConnection a where
  appendEvents conn streamNames batch = liftIO now >>= doAppend
    where
      doAppend ts = do
        debug $ "doAppend ts=" <> show ts
        liftIO . async $
          (modifyPartition conn f >> (head <$> findOrCreateCurrentPartition conn)) >>= \case
            Just e  -> return $ e ^. eventNumber
            Nothing -> panic "full list empty after appending from a NonEmpty list."
        where
          f :: [Event a] -> [Event a]
          f es = (reverse . zipWith toEvent [en..] . toList $ batch) ++ es
            where
              en = maybe initialEventNumber (succ . view eventNumber) . head $ es

          toEvent :: EventNumber -> a -> Event a
          toEvent en payload = Event en streamNames payload ts

  fromNow conn streamNames =
    continueFrom conn streamNames =<< liftIO (succ <$> currentEventNumber conn)

  rangeStream conn _batchSize _streamNames (minE, maxE) = do
    debug $ "rangeStream " <> show (minE, maxE)
    part <- liftIO $ findOrCreateCurrentPartition conn
    debug $ "part: " <> show part
    S.each
      . takeWhile ((>= minE) . view eventNumber)
      . dropWhile ((> maxE)  . view eventNumber)
      <$> liftIO (findOrCreateCurrentPartition conn)
    -- S.each
    --   . takeWhile ((<= maxE) . view eventNumber)
    --   . dropWhile ((< minE)  . view eventNumber)
    --   <$> liftIO (findOrCreateCurrentPartition conn)

continueFrom :: forall m a r. MonadIO m
             => MemConnection a -> [StreamName] -> EventNumber
             -> m (Stream (Of (Event a)) m r)
continueFrom conn streamNames minE = do
  debug $ "continueFrom " <> show minE
  events' <- liftIO $ findOrCreateCurrentPartition conn
  -- TODO: non-sleep based solution
  case elligible events' of
    []    -> do
      debug $ "no elligible events -- sleep 0.25 and continue from " <> show minE
      sleep 0.25 >> continueFrom conn streamNames minE
    (e:_) -> do
      debug $ "elligible event " <> show (e ^. eventNumber)
      debug $ "continuing from " <> show (succ $ e ^. eventNumber)
      debug $ "S.cons " <> show (e ^. eventNumber)

      return $ S.yield e >>= (const . join . lift . continueFrom conn streamNames $ succ (e ^. eventNumber))
  where
    elligible = filter (matchesStreams streamNames)
      . dropWhile ((< minE) . view eventNumber)

    matchesStreams :: [StreamName] -> Event a -> Bool
    matchesStreams _ _ = True  -- TODO

-- -- TODO: surely this can be cleaned up?
-- currentEventNumber :: MemConnection a -> IO EventNumber
-- currentEventNumber conn = fromMaybe initialEventNumber
--   <$> join . fmap (fmap (view eventNumber) . head) . Map.lookup (conn ^. partitionName)
--   <$> (atomically . readTVar $ conn ^. (client . partitions))

-- currentStream :: (EventData a, MonadResource m)
--               => MemConnection a -> BatchSize -> [StreamName]
--               -> m (Stream (Of (Event a)) m ())
-- currentStream conn = currentStreamFrom conn initialEventNumber

-- fromEventNumber :: forall m a r. (EventData a, MonadResource m)
--                 => MemConnection a -> EventNumber -> BatchSize
--                 -> m (Stream (Of (Event a)) m r)
-- fromEventNumber conn = Catchup.make $ Catchup.Config
--   (currentEventNumber conn)
--   (currentStreamFrom conn)
--   (fromEventNumber conn)
--   (fromNow conn)
--   (rangeStream conn)

findOrCreateCurrentPartition :: MemConnection a -> IO [Event a]
findOrCreateCurrentPartition conn = fromMaybe [] . Map.lookup (conn ^. partitionName)
  <$> (atomically . readTVar $ conn ^. (client . partitions))

modifyPartition :: MemConnection a ->  ([Event a] -> [Event a]) -> IO ()
modifyPartition conn f = atomically . modifyTVar (conn ^. (client . partitions))
  $ Map.alter (Just . f . fromMaybe []) (conn ^. partitionName)
