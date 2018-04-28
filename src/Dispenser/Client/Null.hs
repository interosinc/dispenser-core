{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}

module Dispenser.Client.Null
     ( NullClient
     , NullConnection
     , connect
     , appendEvents
     , fromNow
     , rangeStream
     ) where

import Dispenser.Prelude

import Dispenser.Types   ( Client
                         , PartitionConnection
                         , appendEvents
                         , connect
                         , fromNow
                         , initialEventNumber
                         , rangeStream
                         )

data NullClient a = NullClient
  deriving (Eq, Ord, Read, Show)

data NullConnection a = NullConnection
  deriving (Eq, Ord, Read, Show)

instance Client (NullClient a) NullConnection a where
  connect _ _ = return NullConnection

instance PartitionConnection NullConnection a where
  appendEvents _ _ _ = liftIO . async . return $ initialEventNumber

  fromNow _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000

  -- TODO: should be empty instead of bottom, no?
  rangeStream _ _ _ _ = forever . liftIO . threadDelay $ 1000 * 1000 * 1000
