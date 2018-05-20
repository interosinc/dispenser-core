{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}

module Dispenser.Client.Null
     ( NullClient
     , NullConnection
     ) where

import Dispenser.Prelude

import Dispenser.Types
import Dispenser.Functions ( initialEventNumber )

data NullClient a = NullClient
  deriving (Eq, Ord, Read, Show)

data NullConnection a = NullConnection
  deriving (Eq, Ord, Read, Show)

instance Client (NullClient e) NullConnection e where
  connect _ _ = return NullConnection

instance CanAppendEvents NullConnection e where
  appendEvents _ _ _ = return initialEventNumber

instance CanCurrentEventNumber NullConnection e where
  currentEventNumber = const . return $ initialEventNumber

instance CanFromEventNumber NullConnection e where
  fromEventNumber _conn _batchSize _eventNum = return . forever . sleep $ 1000

instance CanRangeStream NullConnection e where
  rangeStream _conn _batchSize _streamNames _range = return mempty

instance PartitionConnection NullConnection e
