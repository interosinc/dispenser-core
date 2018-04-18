{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE ScopedTypeVariables #-}

module TestHelpers where

import           Dispenser.Prelude

import           Dispenser.Memory
import qualified Dispenser.Memory  as Mem
import           Dispenser.Types
import           Streaming

newtype TestInt = TestInt { unTestInt :: Int }
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

testSleep :: IO ()
testSleep = sleep 3 >> return ()
