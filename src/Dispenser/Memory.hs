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
          f [] = map toEvent . toList $ batch
          f events' = foldl g events' (toList batch)
            where
              g :: [Event a] -> a -> [Event a]
              g xs x = toEvent x:xs

          toEvent :: a -> Event a
          toEvent payload = Event eventNumber' streamNames payload ts
            where
              eventNumber' = EventNumber undefined

          _ = batch :: NonEmptyBatch a

  fromNow :: (EventData a, MonadIO m, MonadResource m)
          => MemConnection a
          -> [StreamName]
          -> m (Stream (Of (Event a)) m r)
  fromNow = undefined

  rangeStream :: (EventData a, MonadIO m, MonadResource m)
              => MemConnection a
              -> BatchSize
              -> [StreamName]
              -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event a)) m ())
  rangeStream = undefined

connect :: Text -> MemConnection a
connect = undefined

currentEventNumber :: MemConnection a -> IO EventNumber
currentEventNumber = undefined

currentStream :: Monad m
              => MemConnection a -> BatchSize -> [StreamName]
              -> m (Stream (Of (Event a)) m ())
currentStream conn = currentStreamFrom conn (EventNumber 0)

currentStreamFrom :: MemConnection a
                  -> EventNumber
                  -> BatchSize
                  -> [StreamName]
                  -> m (Stream (Of (Event a)) m ())
currentStreamFrom = undefined

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
