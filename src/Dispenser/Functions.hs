{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Dispenser.Functions
     ( currentStream
     , currentStreamFrom
     , eventNumberDelta
     , fromOne
     , genericFromEventNumber
     , genericFromNow
     , initialEventNumber
     , now
     , postEvent
     ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import           Data.Time.Clock
import           Dispenser.Types
import           Streaming

currentStream :: ( EventData e
                 , CanCurrentEventNumber conn e
                 , CanRangeStream conn e
                 , MonadResource m
                 )
              => conn e -> BatchSize -> StreamSource
              -> m (Stream (Of (Event e)) m ())
currentStream conn batchSize source =
  currentStreamFrom conn batchSize source (EventNumber 0)

currentStreamFrom :: ( EventData e
                     , CanCurrentEventNumber conn e
                     , CanRangeStream conn e
                     , MonadResource m
                     )
                  => conn e -> BatchSize -> StreamSource -> EventNumber
                  -> m (Stream (Of (Event e)) m ())
currentStreamFrom conn batchSize source minE = do
  maxE <- currentEventNumber conn
  rangeStream conn batchSize source (minE, maxE)

eventNumberDelta :: EventNumber -> EventNumber -> Integer
eventNumberDelta (EventNumber n) (EventNumber m) = abs $ fromIntegral n - fromIntegral m

fromOne :: ( EventData e
           , MonadResource m
           , CanFromEventNumber conn e
           )
        => conn e -> BatchSize -> StreamSource -> m (Stream (Of (Event e)) m r)
fromOne conn batchSize source =
  fromEventNumber conn batchSize source initialEventNumber

genericFromEventNumber :: forall conn e m r.
                          ( EventData e
                          , CanFromNow conn e
                          , CanCurrentEventNumber conn e
                          , CanRangeStream conn e
                          , MonadResource m
                          )
                       => conn e -> BatchSize ->  StreamSource -> EventNumber
                       -> m (Stream (Of (Event e)) m r)
genericFromEventNumber conn batchSize source eventNum = do
  debug $ "genericFromEventNumber: eventNum = " <> show eventNum
  clstream <- S.store S.last <$> currentStreamFrom conn batchSize source eventNum
  debug "genericFromEventNumber: returning clstream with continuation"
  return $ clstream >>= \case
    Nothing :> _ -> do
      debug "genericFromEventNumber: init clstream empty, so catchup from 0..."
      catchup initialEventNumber
    Just lastEvent :> _ -> do
      debug "genericFromEventNumber: Got a last event..."
      let lastEventNum = lastEvent ^. eventNumber
          nextEventNum = succ lastEventNum
      debug $ "genericFromEventNumber: lastEventNum=" <> show lastEventNum
      debug $ "genericFromEventNumber: nextEventNum=" <> show nextEventNum
      currentEventNum <- currentEventNumber conn
      debug $ "genericFromEventNumber: currentEventNum=" <> show currentEventNum
      if eventNumberDelta currentEventNum lastEventNum > maxHandOffDelta
        then do
          debug $ "delta greater: fromEventNumber, nextEventNum=" <> show nextEventNum
          join . lift $ genericFromEventNumber conn batchSize source nextEventNum
        else do
          debug $ "delta not greater: catchup, nextEventNum=" <> show nextEventNum
          catchup nextEventNum
  where
    maxHandOffDelta = 50 -- TODO

    catchup en = do
      debug $ "genericFromEventNumber: en=" <> show en
      join . lift . chaseFrom en =<< (join . lift $ fromNow conn batchSize source)

    chaseFrom startNum stream = do
      debug $ "genericFromEventNumber:chaseFrom: startNum="
        <> show startNum <> ", stream=..."
      S.next stream >>= \case
        Left _ -> do
          debug "genericFromEventNumber: S.next->Left -- uh"
          return stream
        Right (pivotEvent, stream') -> do
          debug "genericFromEventNumber: S.next->Right -- uh, missing, etc"
          missingStream <- rangeStream conn batchSize source (startNum, endNum)
          return $ missingStream >>= const (S.yield pivotEvent) >>= const stream'
          where
            endNum = pred $ pivotEvent ^. eventNumber

-- TODO: In most cases it's probably better to implement fromNow yourself and
--       use the other generic implementations based on your fromNow function,
--       but if for some reason it's easier to fromEventNumber then this can be
--       used to implement fromNow in terms of that fromEventNumber.
genericFromNow :: forall conn e m r.
                  ( CanCurrentEventNumber conn e
                  , CanFromEventNumber conn e
                  , EventData e
                  , MonadResource m
                  )
               => conn e -> BatchSize -> StreamSource -> m (Stream (Of (Event e)) m r)
genericFromNow conn batchSize source =
  fromEventNumber conn batchSize source =<< succ <$> currentEventNumber conn

initialEventNumber :: EventNumber
initialEventNumber = EventNumber 1

now :: IO Timestamp
now = Timestamp <$> getCurrentTime

postEvent :: (EventData e, CanAppendEvents conn e, MonadResource m)
          => conn e -> Set StreamName -> e -> m EventNumber
postEvent pc sns e = appendEvents pc sns (NonEmptyBatch $ e :| [])
