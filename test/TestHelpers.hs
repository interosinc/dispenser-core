{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module TestHelpers where

import           Dispenser.Prelude

import           Data.Text                          ( pack )
import           Dispenser.Client.Memory
import qualified Dispenser.Client.Memory  as Client
import           Dispenser.Types
import           System.Random                      ( randomRIO )

newtype TestInt = TestInt { unTestInt :: Int }
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON  TestInt
instance ToJSON    TestInt
instance EventData TestInt

createTestPartition :: IO (MemConnection TestInt)
createTestPartition = do
  client' :: MemClient TestInt <- liftIO $ Client.new
  name <- randomPartitionName
  conn <- liftIO $ connect name client'
  return $ conn
  where
    randomPartitionName :: IO PartitionName
    randomPartitionName = PartitionName
      . ("test_" <>)
      . pack
      <$> replicateM 10 (randomRIO ('a', 'z'))

postTestEvent :: MemConnection TestInt -> Int -> IO ()
postTestEvent conn = (void . wait =<<)
  . runResourceT
  . postEvent conn [StreamName "test"]
  . TestInt

testSleep :: IO ()
testSleep = sleep 3 >> return ()
