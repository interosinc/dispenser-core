{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE TemplateHaskell            #-}

module Dispenser.Types where

import Dispenser.Prelude

import Data.Default
import Streaming

newtype Batch e = Batch { unBatch :: [e] }
  deriving (Applicative, Generic, Eq, Foldable, Functor, Ord, Read, Show)

newtype BatchSize = BatchSize { unBatchSize :: Word }
  deriving (Eq, Generic, Num, Ord, Read, Show)

class PartitionConnection conn e => Client client conn e | client -> conn where
  connect :: MonadIO m => PartitionName -> client -> m (conn e)

-- TODO: DatabaseURL should probably be in .Server... though maybe just "URL" should
--       be here?
newtype DatabaseURL = DatabaseURL { unDatabaseUrl :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

instance Default DatabaseURL where
  def = DatabaseURL "postgres://dispenser@localhost:5432/dispenser"

data Event e = Event
  { _eventNumber  :: EventNumber
  , _eventStreams :: [StreamName]
  , _eventData    :: e
  , _createdAt    :: Timestamp
  } deriving (Eq, Functor, Generic, Ord, Read, Show)

-- TODO: Show a is probably too strong, but for now I'm leaving it.
class ( FromJSON e
      , Generic  e
      , Show     e
      , ToJSON   e
      ) => EventData e

instance EventData ()

newtype EventNumber = EventNumber { unEventNumber :: Integer }
  deriving (Enum, Eq, Generic, Ord, Read, Show)

newtype NonEmptyBatch e = NonEmptyBatch { unNonEmptyBatch :: NonEmpty e }
  deriving (Eq, Foldable, Functor, Generic, Ord, Read, Show)

data Partition = Partition
  { _dbUrl         :: DatabaseURL
  , _partitionName :: PartitionName
  } deriving (Eq, Generic, Ord, Read, Show)

class ( CanAppendEvents conn e
      , CanCurrentEventNumber conn e
      , CanFromEventNumber conn e
      , CanRangeStream conn e
      ) => PartitionConnection conn e

class CanAppendEvents conn e where
  appendEvents :: ( EventData e
                  , MonadResource m
                  )
               => conn e -> [StreamName] -> NonEmptyBatch e -> m EventNumber

class CanCurrentEventNumber conn e where
  currentEventNumber :: MonadResource m => conn e -> m EventNumber

class CanFromEventNumber conn e where
  fromEventNumber :: ( EventData e
                     , MonadResource m
                     )
                  => conn e -> BatchSize -> [StreamName] -> EventNumber
                  -> m (Stream (Of (Event e)) m r)

class CanFromNow conn e where
  fromNow :: ( EventData e
             , MonadResource m
             )
          => conn e -> BatchSize -> [StreamName] -> m (Stream (Of (Event e)) m r)

class CanRangeStream conn e where
  rangeStream :: ( EventData e
                 , MonadResource m
                 )
              => conn e -> BatchSize -> [StreamName] -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event e)) m ())

newtype PoolSize = PoolSize Word
  deriving (Eq, Generic, Ord, Read, Show)

newtype ProjectionName = ProjectionName { unProjectionName :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

newtype StreamName = StreamName { unStreamName :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

newtype PartitionName = PartitionName { unPartitionName :: Text }
  deriving (Eq, Generic, Ord, Read, Show)

newtype Timestamp = Timestamp { unTimestamp :: UTCTime }
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON Timestamp
instance ToJSON   Timestamp

makeClassy ''Event
makeClassy ''Partition
