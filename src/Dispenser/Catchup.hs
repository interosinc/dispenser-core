{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Dispenser.Catchup
     ( catchup
     ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import           Dispenser.Types
import           Streaming

catchup :: forall conn e m r.
           ( EventData e
           , CanFromEventNumber conn e
           , CanFromNow conn e
           , CanCurrentEventNumber conn e
           , CanRangeStream conn e
           , MonadResource m
           )
        => conn e -> BatchSize ->  [StreamName] -> EventNumber
        -> m (Stream (Of (Event e)) m r)
catchup conn batchSize streamNames eventNum = do
  debug $ "Catchup.make:" <> " eventNum = " <> show eventNum
  clstream <- S.store S.last <$> currentStreamFrom conn batchSize streamNames eventNum
  debug "Catchup.make: returning clstream with continuation"
  return $ clstream >>= \case
    Nothing :> _ -> do
      debug "Catchup.make: initial clstream was empty, so moving to catchup from 0..."
      catchup' initialEventNumber
    Just lastEvent :> _ -> do
      debug "Catchup.make: Got a last event..."
      let lastEventNum = lastEvent ^. eventNumber
          nextEventNum = succ lastEventNum
      debug $ "lastEventNum=" <> show lastEventNum
      debug $ "nextEventNum=" <> show nextEventNum
      currentEventNum <- currentEventNumber conn
      debug $ "currentEventNum=" <> show currentEventNum
      if eventNumberDelta currentEventNum lastEventNum > maxHandOffDelta
        then do
          debug $ "delta greater: fromEventNumber, nextEventNum=" <> show nextEventNum
          join . lift $ fromEventNumber conn batchSize nextEventNum
        else do
          debug $ "delta not greater: catchup, nextEventNum=" <> show nextEventNum
          catchup' nextEventNum
  where
    maxHandOffDelta = 50 -- TODO

    catchup' en = do
      debug $ "Catchup.make:catchup: en=" <> show en
      join . lift . chaseFrom en =<< (join . lift $ fromNow conn batchSize)

    chaseFrom startNum stream = do
      debug $ "chaseFrom: startNum=" <> show startNum <> ", stream=..."
      S.next stream >>= \case
        Left _ -> do
          debug "S.next->Left -- uh"
          return stream
        Right (pivotEvent, stream') -> do
          debug "S.next->Right -- uh, missing, etc"
          missingStream <- rangeStream conn batchSize streamNames (startNum, endNum)
          return $ missingStream >> (S.yield pivotEvent) >> stream'
          where
            endNum = pred $ pivotEvent ^. eventNumber
