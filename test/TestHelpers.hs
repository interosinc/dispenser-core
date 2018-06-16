{-# LANGUAGE DeriveDataTypeable  #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving  #-}

module TestHelpers where

import           Dispenser.Prelude

import           Data.Set                          ( fromList )
import           Data.Text                         ( pack )
import           Dispenser.Client.Memory
import qualified Dispenser.Client.Memory as Client
import           Dispenser.Functions               ( postEvent )
import           Dispenser.Types
import           System.Random                     ( randomRIO )

newtype TestInt = TestInt { unTestInt :: Int }
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON  TestInt
instance ToJSON    TestInt
instance EventData TestInt

deriving instance Data TestInt

createTestPartition :: IO (MemConnection TestInt)
createTestPartition = do
  client' :: MemClient TestInt <- liftIO Client.new
  name <- randomPartitionName
  liftIO $ connect name client'
  where
    randomPartitionName :: IO PartitionName
    randomPartitionName = PartitionName
      . ("test_" <>)
      . pack
      <$> replicateM 10 (randomRIO ('a', 'z'))

postTestEvent :: MemConnection TestInt -> Int -> IO ()
postTestEvent conn = void
  . runResourceT
  . postEvent conn (fromList [StreamName "test"])
  . TestInt

testSleep :: IO ()
testSleep = void $ sleep 3
