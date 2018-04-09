{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE InstanceSigs           #-}
{-# LANGUAGE LambdaCase             #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE NoImplicitPrelude      #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TemplateHaskell        #-}

module Dispenser.Memory where

import           Dispenser.Prelude
import qualified Dispenser.Catchup as Catchup
import           Dispenser.Types
import           Streaming
import Control.Concurrent.STM.TVar
import qualified Streaming.Prelude as S

data MemConnection a = MemConnection
  { _memConnectionEvents :: TVar [Event a]
  }

makeFields ''MemConnection

instance forall a. EventData a => PartitionConnection MemConnection a where
  appendEvents :: (EventData a, MonadIO m, MonadResource m)
               => MemConnection a
               -> [StreamName]
               -> NonEmptyBatch a
               -> m (Async EventNumber)
  appendEvents conn streamNames batch = liftIO now >>= doAppend
    where
      doAppend ts = do
        events' :: [Event a] <- liftIO . atomically $ do
          modifyTVar (conn ^. events) f
          readTVar (conn ^. events)
        let lastEventMay :: Maybe (Event a) = lastMay events'
        case lastEventMay of
          Just (e :: Event a)  -> liftIO . async . return $ e ^. eventNumber
          Nothing ->
            panic "somehow after appending events from a NonEmpty, the full list is empty."
        where
          -- TODO: sorts of events' and anything else

          f :: [Event a] -> [Event a]
          f []     = zipWith (curry h) [EventNumber 0..] (toList batch)
          f (x:xs) = foldl g (x:xs) (toList batch)
            where
              g :: [Event a] -> a -> [Event a]
              g [] _ = panic "I thought this couldn't happen?"
              g (e:es) payload = toEvent (succ $ e ^. eventNumber) payload:e:es

          h :: (EventNumber, a) -> Event a
          h (en', payload) = toEvent en' payload

          toEvent :: EventNumber -> a -> Event a
          toEvent en payload = Event en streamNames payload ts

  fromNow :: (EventData a, MonadIO m, MonadResource m)
          => MemConnection a
          -> [StreamName]
          -> m (Stream (Of (Event a)) m r)
  fromNow = panic "Memory.fromNow not impl!"

  rangeStream :: (EventData a, MonadIO m, MonadResource m)
              => MemConnection a
              -> BatchSize
              -> [StreamName]
              -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event a)) m ())
  rangeStream conn _batchSize _streamNames (minE, maxE) = do
    events' :: [Event a] <- liftIO
      . atomically
      . readTVar
      . view events
      $ conn
    return
      . S.takeWhile ((<= maxE) . view eventNumber)
      . S.dropWhile ((< minE) . view eventNumber)
      . S.each
      $ events'

connect :: Text -> MemConnection a
connect = panic "Memory.connect not impl!"

currentEventNumber :: MemConnection a -> IO EventNumber
currentEventNumber conn = do
  events' :: [Event a] <- liftIO . atomically . readTVar $ conn ^. events
  return $ case head events' of
    Nothing -> EventNumber (-1)
    Just e  -> e ^. eventNumber

currentStream :: (EventData a, MonadIO m, MonadResource m)
              => MemConnection a -> BatchSize -> [StreamName]
              -> m (Stream (Of (Event a)) m ())
currentStream conn = currentStreamFrom conn (EventNumber 0)

currentStreamFrom :: (EventData a, MonadIO m, MonadResource m)
                  => MemConnection a -> EventNumber-> BatchSize -> [StreamName]
                  -> m (Stream (Of (Event a)) m ())
currentStreamFrom conn minE batchSize streamNames = do
  maxE <- liftIO $ currentEventNumber conn
  rangeStream conn batchSize streamNames (minE, maxE)

-- recreate = undefined

fromEventNumber :: forall m a r. (EventData a, MonadIO m, MonadResource m)
                => MemConnection a -> EventNumber -> BatchSize
                -> m (Stream (Of (Event a)) m r)
fromEventNumber conn = Catchup.make $ Catchup.Config
  (currentEventNumber conn)
  (currentStreamFrom conn)
  (fromEventNumber conn)
  (fromNow conn)
  (rangeStream conn)

-- TODO: make this generic over some class that fromEventNumber is in
-- TODO: see also Server/pg
fromZero :: (EventData a, MonadIO m, MonadResource m)
         => MemConnection a -> BatchSize
         -> m (Stream (Of (Event a)) m r)
fromZero conn = fromEventNumber conn (EventNumber 0)
