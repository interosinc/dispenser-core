{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

module MemorySpec ( main, spec ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude            as S

import           Control.Monad.Trans.Resource
import           Dispenser.Memory
import qualified Dispenser.Memory             as Mem
import           Dispenser.Types
import           Streaming
import           Test.Hspec
import           TestHelpers

main :: IO ()
main = hspec . after_ (sleep logDelay) $ spec
  where
    logDelay = 0.2

spec :: Spec
spec = -- let batchSizes = [1..10] in
  let batchSizes = [1] in
  describe "Dispenser.Memory" $ forM_ (map BatchSize batchSizes) $ \batchSize -> do
  context ("with " <> show batchSize) $ do

    context "given a stream with 3 events in it" $ do
      let testStream = makeTestStream batchSize 3

      -- WORKING
      it "should be able to take the first 2 immediately" $ do
        src <- snd <$> runResourceT testStream
        complete <- race testSleep $ do
          let stream = S.take 2 src
          xs <- runResourceT (S.fst' <$> S.toList stream)
          sort (map (unEventNumber . view eventNumber) xs) `shouldBe` [1, 2]
        complete `shouldBe` Right ()

      -- WRONG ANSWER
      it "should be able to take 5 if two more are posted asynchronously" $ do
        (conn, stream) <- runResourceT testStream
        complete <- race testSleep $ do
          void . forkIO $ do
            sleep 0.05 >> postTestEvent conn 4
            sleep 0.05 >> postTestEvent conn 5
            sleep 0.05 >> postTestEvent conn 6
          let stream' = S.take 5 stream
          xs <- runResourceT (S.fst' <$> S.toList stream')
          map (view eventData) xs `shouldBe` map TestInt [1..5]
        complete `shouldBe` Right ()

    context "given a stream with 10 events in it" $ do
      let testStream = makeTestStream batchSize 10

      -- TIMING OUT
      it "should be able to take all 10" $ do
        complete <- race testSleep $ do
          stream <- S.take 10 . snd <$> runResourceT testStream
          xs <- runResourceT (S.fst' <$> S.toList stream)
          map (unEventNumber . view eventNumber) xs `shouldBe` [1..10]
          sum (map (unTestInt . view eventData) xs) `shouldBe` 55
          return ()
        complete `shouldBe` Right ()

      -- NOT WORKING
      it "should be able to take 15 if 5 are posted asynchronously" $ do
        (conn, stream) <- runResourceT testStream
        complete <- race testSleep $ do
          void . forkIO $ mapM_ ((sleep 0.05 >>) . postTestEvent conn) [11..15]
          let stream' = S.take 15 stream
          xs <- runResourceT (S.fst' <$> S.toList stream')
          map (view eventData) xs `shouldBe` map TestInt [1..15]
        complete `shouldBe` Right ()

makeTestStream :: (MonadIO m, MonadResource m)
               => BatchSize -> Int
               -> m (MemConnection TestInt, Stream (Of (Event TestInt)) m r)
makeTestStream batchSize n = do
  conn <- liftIO createTestPartition
  mapM_ (liftIO . postTestEvent conn) [1..n]
  (conn,) <$> fromZero conn batchSize

tempFoo :: IO (MemConnection TestInt)
tempFoo = fst <$> (runResourceT $ makeTestStream (BatchSize 1) 2)

tempBar :: IO (MemConnection TestInt)
tempBar = Mem.connect
