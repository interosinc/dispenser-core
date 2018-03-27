{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE LambdaCase                #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NoImplicitPrelude         #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE RecordWildCards           #-}
{-# LANGUAGE TemplateHaskell           #-}

module Dispenser.Catchup
     ( Config( Config )
     , make
     ) where

import Dispenser.Prelude
import Dispenser.Types
import Streaming
import qualified Streaming.Prelude as S

data Config m a r where
  Config :: (EventData a, MonadIO m)
         => IO EventNumber                                                                                -- currentEventNumber
         -> (EventNumber -> BatchSize -> [StreamName] -> m (Stream (Of (Event a)) m ()))                  -- currentStreamFrom
         -> (EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r))                                   -- fromEventNumber
         -> ([StreamName] -> m (Stream (Of (Event a)) m r))                                               -- fromNow
         -> (BatchSize -> [StreamName] -> (EventNumber, EventNumber) -> m (Stream (Of (Event a)) m ()))   -- rangeStream
         -> Config m a r

make :: forall m a r. (EventData a, MonadIO m)
     => Config m a r -> EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r)
make config eventNum batchSize = do
  clstream <- S.store S.last <$> currentStreamFrom eventNum batchSize streamNames
  return $ clstream >>= \case
    Nothing :> _ -> catchup (EventNumber 0)
    Just lastEvent :> _ -> do
      let lastEventNum = lastEvent ^. eventNumber
          nextEventNum = succ lastEventNum
      currentEventNum <- liftIO $ currentEventNumber
      if eventNumberDelta currentEventNum lastEventNum > maxHandOffDelta
        then join . lift $ fromEventNumber nextEventNum batchSize
        else catchup nextEventNum
    where
      Config currentEventNumber currentStreamFrom fromEventNumber fromNow' rangeStream'
        = config

      maxHandOffDelta = 50 -- TODO

      streamNames = [] -- TODO

      catchup en = join . lift $ fromNow' streamNames >>= chaseFrom en

      chaseFrom startNum stream = S.next stream >>= \case
        Left _ -> return stream
        Right (pivotEvent, stream') -> do
          missingStream <- rangeStream' batchSize streamNames (startNum, endNum)
          return $ missingStream >>= const (S.yield pivotEvent) >>= const stream'
          where
            endNum = pred $ pivotEvent ^. eventNumber

