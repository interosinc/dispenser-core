{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}

module Dispenser.Types where

import Dispenser.Prelude

import Data.Default
import Data.Time.Clock
import Streaming

newtype Batch a = Batch { unBatch :: [a] }
  deriving (Applicative, Generic, Eq, Foldable, Functor, Ord, Read, Show)

newtype BatchSize = BatchSize { unBatchSize :: Word }
  deriving (Eq, Generic, Num, Ord, Read, Show)

class PartitionConnection conn a => Client client conn a | client -> conn where
  connect :: MonadIO m => PartitionName -> client -> m (conn a)

newtype DatabaseURL = DatabaseURL { unDatabaseUrl :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

instance Default DatabaseURL where
  def = DatabaseURL "postgres://dispenser@localhost:5432/dispenser"

data Event a = Event
  { _eventNumber  :: EventNumber
  , _eventStreams :: [StreamName]
  , _eventData    :: a
  , _createdAt    :: Timestamp
  } deriving (Eq, Functor, Generic, Ord, Read, Show)

-- TODO: Show a is probably too strong?
-- TODO: Should we require Generic?
class (FromJSON a, ToJSON a, Show a) => EventData a

newtype EventNumber = EventNumber { unEventNumber :: Integer }
  deriving (Enum, Eq, Generic, Ord, Read, Show)

eventNumberDelta :: EventNumber -> EventNumber -> Integer
eventNumberDelta (EventNumber n) (EventNumber m) =
  abs $ fromIntegral n - fromIntegral m

newtype NonEmptyBatch a = NonEmptyBatch { unNonEmptyBatch :: NonEmpty a }
  deriving (Eq, Foldable, Functor, Generic, Ord, Read, Show)

data Partition = Partition
  { _dbUrl         :: DatabaseURL
  , _partitionName :: PartitionName
  } deriving (Eq, Generic, Ord, Read, Show)

class PartitionConnection pc a where
  appendEvents :: (EventData a, MonadIO m, MonadResource m)
               => pc a -> [StreamName] -> NonEmptyBatch a -> m (Async EventNumber)
  fromNow :: (EventData a, MonadIO m, MonadResource m)
          => pc a -> [StreamName] -> m (Stream (Of (Event a)) m r)
  rangeStream :: (EventData a, MonadIO m, MonadResource m)
              => pc a -> BatchSize -> [StreamName] -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event a)) m ())

postEvent :: (EventData a, PartitionConnection pc a, MonadIO m, MonadResource m)
          => pc a -> [StreamName] -> a -> m (Async EventNumber)
postEvent pc sns e = appendEvents pc sns (NonEmptyBatch $ e :| [])

newtype PoolSize = PoolSize Word
  deriving (Eq, Generic, Ord, Read, Show)

newtype StreamName = StreamName { unStreamName :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

newtype PartitionName = PartitionName { unPartitionName :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

newtype Timestamp = Timestamp { unTimestamp :: UTCTime }
  deriving (Eq, Generic, Ord, Read, Show)

now :: IO Timestamp
now = Timestamp <$> getCurrentTime

instance FromJSON Timestamp
instance ToJSON   Timestamp

makeClassy ''Event
makeClassy ''Partition
