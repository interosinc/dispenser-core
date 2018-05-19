{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
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

eventNumberDelta :: EventNumber -> EventNumber -> Integer
eventNumberDelta (EventNumber n) (EventNumber m) = abs $ fromIntegral n - fromIntegral m

newtype NonEmptyBatch a = NonEmptyBatch { unNonEmptyBatch :: NonEmpty a }
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
                  => conn e -> BatchSize -> EventNumber -> m (Stream (Of (Event e)) m r)

class CanFromNow conn e where
  fromNow :: ( EventData e
             , MonadResource m
             )
          => conn e -> BatchSize -> m (Stream (Of (Event e)) m r)

-- TODO: Should we really separate fromNow and fromEventNumber or should fromNow
--       be the only primitive for this stuff?  If we went that route we should
--       be able to express continueFrom in terms of canRangeStream +
--       continueFromNow generically, which is what our original Catchup
--       template did? Also what's the difference between continueFrom and
--       fromEventNumber? can the former be replaced entirely with the later?

-- TODO: make sure that it's possible to implement any particular function for
--       efficiency, but that if you don't need/want to do that you can
--       implement and entire PartitionConnection in as few functions / as
--       little code as possible
genericFromNow :: forall conn e m r.
                  ( CanCurrentEventNumber conn e
                  , CanFromEventNumber conn e
                  , EventData e
                  , MonadResource m
                  )
               => conn e -> BatchSize -> m (Stream (Of (Event e)) m r)
genericFromNow conn batchSize = do
  en <- succ <$> currentEventNumber conn
  fromEventNumber conn batchSize en

currentStream :: ( EventData e
                 , CanCurrentEventNumber conn e
                 , CanRangeStream conn e
                 , MonadResource m
                 )
              => conn e -> BatchSize -> [StreamName]
              -> m (Stream (Of (Event e)) m ())
currentStream conn batchSize streamNames =
  currentStreamFrom conn batchSize streamNames (EventNumber 0)

currentStreamFrom :: ( EventData e
                     , CanCurrentEventNumber conn e
                     , CanRangeStream conn e
                     , MonadResource m
                     )
                  => conn e -> BatchSize -> [StreamName] -> EventNumber
                  -> m (Stream (Of (Event e)) m ())
currentStreamFrom conn batchSize streamNames minE = do
  maxE <- currentEventNumber conn
  rangeStream conn batchSize streamNames (minE, maxE)

defaultFromNow :: ( EventData e
                  , CanFromEventNumber conn e
                  , CanCurrentEventNumber conn e
                  , MonadIO m
                  , MonadResource m
                  )
               => conn e -> BatchSize -> [StreamName] -> m (Stream (Of (Event e)) m r)
defaultFromNow conn batchSize _streamNames =
  -- TODO: filter by stream names? remove stream names?  is this where
  -- filtering should go ? it needs to be as low level as possible so that eg
  -- as few events leave the db as possible, etc.
  fromEventNumber conn batchSize =<< currentEventNumber conn

class CanRangeStream conn e where
  rangeStream :: ( EventData e
                 , MonadResource m
                 )
              => conn e -> BatchSize -> [StreamName] -> (EventNumber, EventNumber)
              -> m (Stream (Of (Event e)) m ())

postEvent :: ( EventData e
             , CanAppendEvents conn e
             , MonadResource m
             )
          => conn e -> [StreamName] -> e -> m EventNumber
postEvent pc sns e = appendEvents pc sns (NonEmptyBatch $ e :| [])

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

now :: IO Timestamp
now = Timestamp <$> getCurrentTime

instance FromJSON Timestamp
instance ToJSON   Timestamp

makeClassy ''Event
makeClassy ''Partition

initialEventNumber :: EventNumber
initialEventNumber = EventNumber 1

-- TODO: make this generic over some class that fromEventNumber is in
-- TODO: see also Server/pg
fromOne :: ( EventData e
           , MonadResource m
           , PartitionConnection conn e
           )
        => conn e -> BatchSize -> m (Stream (Of (Event e)) m r)
fromOne conn batchSize = fromEventNumber conn batchSize initialEventNumber
