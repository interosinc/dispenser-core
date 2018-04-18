{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}

module Dispenser.NullClient ( NullClient, NullConnection ) where

import Dispenser.Prelude

import Dispenser.Types   ( BatchSize
                         , Client
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

data NullClient a = NullClient
  deriving (Eq, Ord, Read, Show)

data NullConnection a = NullConnection
  deriving (Eq, Ord, Read, Show)

instance Client (NullClient a) NullConnection a where
  connect :: MonadIO m => PartitionName -> NullClient a -> m (NullConnection a)
  connect _ _ = return NullConnection

instance PartitionConnection NullConnection a where
  appendEvents :: MonadIO m
               => NullConnection a
               -> [StreamName]
               -> NonEmptyBatch a
               -> m (Async EventNumber)
  appendEvents _ _ _ = liftIO . async . return $ initialEventNumber

  fromNow :: MonadIO m
          => NullConnection a
          -> [StreamName]
          -> m (Stream (Of (Event a)) m r)
  fromNow _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000

  rangeStream :: MonadIO m
              => NullConnection a
              -> BatchSize
              -> [StreamName]
              -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event a)) m r)
  -- TODO: should be empty instead of bottom, no?
  rangeStream _ _ _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000
