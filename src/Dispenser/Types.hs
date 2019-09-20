{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE TemplateHaskell            #-}

module Dispenser.Types where

import           Dispenser.Prelude

import           Data.Default
import qualified Data.Semigroup            as Semi
import qualified Data.Set                  as Set
import           Streaming
import           Test.QuickCheck
import           Test.QuickCheck.Instances         ()

newtype Batch e = Batch { unBatch :: [e] }
  deriving (Data, Applicative, Generic, Eq, Foldable, Functor, Ord, Read, Show)

newtype BatchSize = BatchSize { unBatchSize :: Word }
  deriving (Data, Eq, Generic, Num, Ord, Read, Show)

class PartitionConnection conn m e => Client client conn m e | client -> conn where
  connect :: PartitionName -> client -> m (conn e)

-- TODO: DatabaseURL should probably be in .Server... though maybe just "URL" should
--       be here?
newtype DatabaseURL = DatabaseURL { unDatabaseUrl :: Text }
  deriving (Data, Eq, Generic, Ord, Read, Show)

instance Default DatabaseURL where
  def = DatabaseURL "postgres://dispenser@localhost:5432/dispenser"

data Event e = Event
  { _eventNumber  :: EventNumber
  , _eventStreams :: Set StreamName
  , _eventData    :: e
  , _recordedAt   :: Timestamp
  } deriving (Data, Eq, Functor, Generic, Ord, Read, Show)

-- TODO: Show a is probably too strong, but for now I'm leaving it.
class ( Data         e
      , FromJSON     e
      , Generic      e
      , Show         e
      , ToJSON       e
      ) => EventData e

instance EventData ()

newtype EventNumber = EventNumber { unEventNumber :: Integer }
  deriving (Data, Enum, Eq, Generic, Ord, Read, Show)

newtype NonEmptyBatch e = NonEmptyBatch { unNonEmptyBatch :: NonEmpty e }
  deriving (Data, Eq, Foldable, Functor, Generic, Ord, Read, Show)

data Partition = Partition
  { _dbUrl         :: DatabaseURL
  , _partitionName :: PartitionName
  } deriving (Data, Eq, Generic, Ord, Read, Show)

type PartitionConnection  conn m e =
  ( CanAppendEvents       conn m e
  , CanCurrentEventNumber conn m e
  , CanFromEventNumber    conn m e
  , CanRangeStream        conn m e
  )

class ( EventData e, MonadResource m ) => CanAppendEvents conn m e where
  appendEvents :: conn e -> Set StreamName -> NonEmptyBatch e -> m EventNumber

class CanCurrentEventNumber conn m e where
  currentEventNumber :: MonadResource m => conn e -> m EventNumber

class CanFromEventNumber conn m e where
  fromEventNumber :: ( EventData e, MonadResource m )
                  => conn e -> BatchSize -> StreamSource -> EventNumber
                  -> m (Stream (Of (Event e)) m r)

class CanFromNow conn m e where
  fromNow :: ( EventData e, MonadResource m )
          => conn e -> BatchSize -> StreamSource
          -> m (Stream (Of (Event e)) m r)

class CanRangeStream conn m e where
  rangeStream :: ( EventData e, MonadResource m )
              => conn e -> BatchSize -> StreamSource -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event e)) m ())

newtype PoolSize = PoolSize { unPoolSize :: Word }
  deriving (Data, Eq, Generic, Ord, Read, Show)

newtype ProjectionName = ProjectionName { unProjectionName :: Text }
  deriving (Data, Eq, Generic, Ord, Read, Show)

newtype StreamName = StreamName { unStreamName :: Text }
  deriving (Data, Eq, Generic, Ord, Read, Show)

data StreamSource
  = AllStreams
  | SomeStreams (Set StreamName)
  deriving (Data, Eq, Generic, Ord, Read, Show)

instance Semigroup StreamSource where
  SomeStreams a <> SomeStreams b = SomeStreams (a <> b)
  AllStreams    <> _             = AllStreams
  _             <> AllStreams    = AllStreams

instance Monoid StreamSource where
  mempty  = SomeStreams mempty
  mappend = (Semi.<>)

instance Zero StreamSource where
  zero = AllStreams

singletonSource :: StreamName -> StreamSource
singletonSource = SomeStreams . Set.singleton

sourceFromList :: [StreamName] -> StreamSource
sourceFromList = mconcat . map singletonSource

sourceCount :: StreamSource -> Word
sourceCount (SomeStreams xs) = fromIntegral . Set.size $ xs
sourceCount AllStreams       = 0

newtype PartitionName = PartitionName { unPartitionName :: Text }
  deriving (Data, Eq, Generic, Ord, Read, Show)

newtype Timestamp = Timestamp { unTimestamp :: UTCTime }
  deriving (Data, Eq, FromJSON, Generic, Ord, Read, Show, ToJSON)

makeClassy ''Event
makeClassy ''Partition
makeClassy ''StreamSource

instance Arbitrary StreamName where
  shrink    = genericShrink
  arbitrary = StreamName <$> arbitrary

instance Arbitrary StreamSource where
  shrink    = genericShrink
  arbitrary = frequency
    [ (1, pure AllStreams)
    , (1, pure zero)
    , (1, pure $ SomeStreams mempty)
    , (7, SomeStreams <$> arbitrary)
    ]
