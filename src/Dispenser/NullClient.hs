{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}

module Dispenser.NullClient ( NullClient, NullConnection ) where
import Dispenser.Prelude

import Dispenser.Types ( Client
                       , Event
                       , EventNumber( EventNumber )
                       , NonEmptyBatch
                       , PartitionConnection
                       , PartitionName
                       , StreamName
                       , appendEvents
                       , connect
                       , fromNow
                       , rangeStream
                       )
import Streaming

data NullClient = NullClient
  deriving (Eq, Ord, Read, Show)

data NullConnection = NullConnection
  deriving (Eq, Ord, Read, Show)

instance Client NullClient NullConnection where
  connect :: MonadIO m => PartitionName -> NullClient -> m NullConnection
  connect _ _ = return NullConnection

instance PartitionConnection NullConnection where
  appendEvents :: MonadIO m
               => [StreamName]
               -> NonEmptyBatch a
               -> NullConnection
               -> m (Async EventNumber)
  appendEvents _ _ _ = liftIO . async . return $ EventNumber 0

  fromNow :: MonadIO m
          => [StreamName]
          -> NullConnection
          -> m (Stream (Of (Event a)) m r)
  fromNow _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000

  rangeStream :: MonadIO m
              => [StreamName]
              -> (EventNumber, EventNumber)
              -> NullConnection
              -> m (Stream (Of (Event a)) m r)
  rangeStream _ _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000
