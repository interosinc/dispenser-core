{-# LANGUAGE ConstraintKinds               #-}
{-# LANGUAGE FlexibleContexts              #-}
{-# LANGUAGE FlexibleInstances             #-}
{-# LANGUAGE InstanceSigs                  #-}
{-# LANGUAGE MonoLocalBinds                #-}
{-# LANGUAGE MultiParamTypeClasses         #-}
{-# LANGUAGE NoImplicitPrelude             #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module Dispenser.Client.Null
  ( NullClient
  , NullConnection
  ) where

import Dispenser.Prelude

import Dispenser.Functions ( initialEventNumber )
import Dispenser.Types

data NullClient a = NullClient
  deriving (Eq, Ord, Read, Show)

data NullConnection a = NullConnection
  deriving (Eq, Ord, Read, Show)

instance (EventData e, MonadResource m)
  => Client (NullClient e) NullConnection m e where
  connect _ _ = return NullConnection

instance (EventData e, MonadResource m) => CanAppendEvents NullConnection m e where
  appendEvents :: NullConnection e
               -> Set StreamName
               -> NonEmptyBatch e
               -> m EventNumber
  appendEvents _ _ _ = return initialEventNumber

instance CanCurrentEventNumber NullConnection m e where
  currentEventNumber = const . return $ initialEventNumber

instance CanFromEventNumber NullConnection m e where
  fromEventNumber _conn _batchSize _eventNum = return . forever . sleep $ 1000

instance CanRangeStream NullConnection m e where
  rangeStream _conn _batchSize _streamNames _range = return mempty

_proof :: PartitionConnection NullConnection m e => Proxy (m e)
_proof = Proxy
