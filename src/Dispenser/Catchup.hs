{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE LambdaCase                #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NoImplicitPrelude         #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE RankNTypes                #-}

module Dispenser.Catchup
     ( Config( Config )
     , make
     ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import           Dispenser.Types
import           Streaming

data Config m a r where
  Config :: (EventData a, MonadIO m)
         => IO EventNumber                                                                                -- currentEventNumber
         -> (EventNumber -> BatchSize -> [StreamName] -> m (Stream (Of (Event a)) m ()))                  -- currentStreamFrom
         -> (EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r))                                   -- fromEventNumber
         -> ([StreamName] -> m (Stream (Of (Event a)) m r))                                               -- fromNow
         -> (BatchSize -> [StreamName] -> (EventNumber, EventNumber) -> m (Stream (Of (Event a)) m ()))   -- rangeStream
         -> Config m a r

make :: forall m a r. MonadIO m
     => Config m a r -> EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r)
make config eventNum batchSize = do
  debug $ "Catchup.make:" <> " eventNum = " <> show eventNum
  clstream <- S.store S.last <$> currentStreamFrom eventNum batchSize streamNames
  debug "Catchup.make: returning clstream with continuation"
  return $ clstream >>= \case
    Nothing :> _ -> do
      debug "Catchup.make: initial clstream was empty, so moving to catchup from 0..."
      catchup initialEventNumber
    Just lastEvent :> _ -> do
      debug "Catchup.make: Got a last event..."
      let lastEventNum = lastEvent ^. eventNumber
          nextEventNum = succ lastEventNum
      debug $ "lastEventNum=" <> show lastEventNum
      debug $ "nextEventNum=" <> show nextEventNum
      currentEventNum <- liftIO currentEventNumber
      debug $ "currentEventNum=" <> show currentEventNum
      if eventNumberDelta currentEventNum lastEventNum > maxHandOffDelta
        then do
          debug $ "delta greater: fromEventNumber, nextEventNum=" <> show nextEventNum
          join . lift $ fromEventNumber nextEventNum batchSize
        else do
          debug $ "delta not greater: catchup, nextEventNum=" <> show nextEventNum
          catchup nextEventNum
    where
      Config currentEventNumber currentStreamFrom fromEventNumber fromNow' rangeStream'
        = config

      maxHandOffDelta = 50 -- TODO

      streamNames = [] -- TODO

      catchup en = do
        debug $ "Catchup.make:catchup: en=" <> show en
        join . lift $ fromNow' streamNames >>= chaseFrom en

      chaseFrom startNum stream = do
        debug $ "chaseFrom: startNum=" <> show startNum <> ", stream=..."
        S.next stream >>= \case
          Left _ -> do
            debug "S.next->Left -- uh"
            return stream
          Right (pivotEvent, stream') -> do
            debug "S.next->Right -- uh, missing, etc"
            missingStream <- rangeStream' batchSize streamNames (startNum, endNum)
            return $ missingStream >>= const (S.yield pivotEvent) >>= const stream'
            where
              endNum = pred $ pivotEvent ^. eventNumber
