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
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import qualified Dispenser.Catchup           as Catchup
import           Dispenser.Types
import           Streaming

newtype MemConnection a = MemConnection
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
        debug $ "doAppend ts=" <> show ts
        deleteMeBefore <- liftIO . atomically . readTVar $ conn ^. events
        debug $ "before: " <> show deleteMeBefore
        events' :: [Event a] <- liftIO . atomically $ do
          modifyTVar (conn ^. events) f
          readTVar (conn ^. events)
        debug $ "after: " <> show events'
        case head events' :: Maybe (Event a) of
          Just (e :: Event a)  -> liftIO . async . return $ e ^. eventNumber
          Nothing ->
            panic "somehow after appending events from a NonEmpty, the full list is empty."
        where
          f :: [Event a] -> [Event a]
          f es = (reverse . zipWith toEvent [en..] . toList $ batch) ++ es
            where
              en = maybe initialEventNumber
                (succ . view eventNumber)
                . head
                $ es

          toEvent :: EventNumber -> a -> Event a
          toEvent en payload = Event en streamNames payload ts

  fromNow :: (EventData a, MonadIO m, MonadResource m)
          => MemConnection a
          -> [StreamName]
          -> m (Stream (Of (Event a)) m r)
  fromNow conn streamNames =
    continueFrom conn streamNames =<< liftIO (currentEventNumber conn)

  rangeStream :: (EventData a, MonadIO m, MonadResource m)
              => MemConnection a
              -> BatchSize
              -> [StreamName]
              -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event a)) m ())
  rangeStream conn _batchSize _streamNames (minE, maxE) = do
    debug $ "rangeStream " <> show (minE, maxE)
    events' :: [Event a]
      <- (reverse <$>)
      . liftIO
      . atomically
      . readTVar
      . view events
      $ conn
    let events'' :: [Event a] = dropWhile ((< minE) . view eventNumber) events'
    return $ if null events''
      then mempty
      else S.each $ takeWhile ((<= maxE) . view eventNumber) events''

continueFrom :: forall m a r. MonadIO m
             => MemConnection a -> [StreamName] -> EventNumber
             -> m (Stream (Of (Event a)) m r)
continueFrom conn streamNames minE = do
  debug $ "continueFrom " <> show minE
  -- TODO: perf
  events' :: [Event a]
    <- (reverse <$>)
    . liftIO
    . atomically
    . readTVar
    . view events
    $ conn
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

connect :: MonadIO m => m (MemConnection a)
connect = (MemConnection <$>) . liftIO . atomically . newTVar $ []

currentEventNumber :: MemConnection a -> IO EventNumber
currentEventNumber conn = do
  events' :: [Event a] <- liftIO . atomically . readTVar $ conn ^. events
  return $ case head events' of
    Nothing -> pred initialEventNumber
    Just e  -> e ^. eventNumber

currentStream :: (EventData a, MonadIO m, MonadResource m)
              => MemConnection a -> BatchSize -> [StreamName]
              -> m (Stream (Of (Event a)) m ())
currentStream conn = currentStreamFrom conn initialEventNumber

currentStreamFrom :: (EventData a, MonadIO m, MonadResource m)
                  => MemConnection a -> EventNumber-> BatchSize -> [StreamName]
                  -> m (Stream (Of (Event a)) m ())
currentStreamFrom conn minE batchSize streamNames = do
  maxE <- liftIO $ currentEventNumber conn
  rangeStream conn batchSize streamNames (minE, maxE)

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
-- TODO: should be renamed to fromInitial or something since initial is now 1
-- (or we should go back to zero and fix the pg schema).
fromZero :: (EventData a, MonadIO m, MonadResource m)
         => MemConnection a -> BatchSize
         -> m (Stream (Of (Event a)) m r)
fromZero conn = fromEventNumber conn initialEventNumber
