{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE ScopedTypeVariables #-}

module TestHelpers where

import Dispenser.Prelude

import Streaming
import Dispenser.Types
import Dispenser.Memory
import qualified Dispenser.Memory as Mem

newtype TestEvent = TestEvent Int
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON TestEvent
instance ToJSON   TestEvent

instance EventData TestEvent

type TestStream a = Stream (Of (Event TestEvent)) IO a

newtype TestInt = TestInt Int
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON  TestInt
instance ToJSON    TestInt
instance EventData TestInt

createTestPartition :: MonadIO m => m (MemConnection a)
createTestPartition = Mem.connect

postTestEvent :: MemConnection TestInt -> Int -> IO ()
postTestEvent conn = (void . wait =<<)
  . runResourceT
  . postEvent conn [StreamName "test"]
  . TestInt
