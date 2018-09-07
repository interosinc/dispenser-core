{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}

module MemorySpec ( main, spec ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude            as S

import           Control.Monad.Trans.Resource
import           Data.Set
import           Dispenser.Client.Memory
import           Dispenser.Functions
import           Dispenser.Types
import           Streaming
import           Test.Hspec
import           TestHelpers

main :: IO ()
main = hspec . after_ (sleep logDelay) $ spec
  where
    logDelay = 0.02

spec :: Spec
spec = let batchSizes = [1..10] in
  describe "Dispenser.Clients.Memory" $ forM_ (fmap BatchSize batchSizes) $

    \batchSize -> context ("with " <> show batchSize) $ do

      context "given a stream with 3 events in it" $ do
        let testStream = makeTestStream batchSize 3
            source     = testStreamSource

        it "should be able to rangeStream 1..3 right away" $ do
          conn <- fst <$> runResourceT testStream
          events <- runResourceT $ do
            stream <- rangeStream conn batchSize source
              ( EventNumber 1
              , EventNumber 3
              )
            S.fst' <$> S.toList (S.map (view eventData) stream)
          events `shouldBe` fmap TestInt [1..3]

        it "should be able to take the available events twice in a row" $ do
          conn <- fst <$> runResourceT testStream
          curEventNum <- runResourceT $ currentEventNumber conn
          let numAvail = fromIntegral . unEventNumber $ curEventNum

          results1 <- runResourceT $ do
            events <- fromOne conn batchSize source
            S.fst' <$> S.toList (S.map (view eventData) . S.take numAvail $ events)
          results1 `shouldBe` fmap TestInt [1..3]

          results2 <- runResourceT $ do
            events <- fromOne conn batchSize source
            S.fst' <$> S.toList (S.map (view eventData) . S.take numAvail $ events)
          results2 `shouldBe` fmap TestInt [1..3]

          -- if it makes it here it succeeds... TODO: there's probably a way to
          -- express that better in hspec than this fake assertion.
          1 `shouldBe` (1 :: Int)

        it "should be able to take the first 2 immediately" $ do
          src <- snd <$> runResourceT testStream
          complete <- race testSleep $ do
            let stream = S.take 2 src
            xs <- runResourceT (S.fst' <$> S.toList stream)
            sort (fmap (unEventNumber . view eventNumber) xs) `shouldBe` [1, 2]
          complete `shouldBe` Right ()

        it "should be able to take 5 if two more are posted asynchronously" $ do
          (conn, stream) <- runResourceT testStream
          complete <- race testSleep $ do
            void . forkIO $ do
              sleep 0.05 >> postTestEvent conn 4
              sleep 0.05 >> postTestEvent conn 5
              sleep 0.05 >> postTestEvent conn 6
            let stream' = S.take 5 stream
            xs <- runResourceT (S.fst' <$> S.toList stream')
            fmap (view eventData) xs `shouldBe` fmap TestInt [1..5]
          complete `shouldBe` Right ()

      context "given a stream with 10 events in it" $ do
        let testStream = makeTestStream batchSize 10

        it "should be able to take all 10" $ do
          complete <- race testSleep $ do
            stream <- S.take 10 . snd <$> runResourceT testStream
            xs <- runResourceT (S.fst' <$> S.toList stream)
            fmap (unEventNumber . view eventNumber) xs `shouldBe` [1..10]
            sum (fmap (unTestInt . view eventData) xs) `shouldBe` 55
            return ()
          complete `shouldBe` Right ()

        it "should be able to take 15 if 5 are posted asynchronously" $ do
          (conn, stream) <- runResourceT testStream
          complete <- race testSleep $ do
            void . forkIO $ mapM_ ((sleep 0.05 >>) . postTestEvent conn) [11..15]
            let stream' = S.take 15 stream
            xs <- runResourceT (S.fst' <$> S.toList stream')
            fmap (view eventData) xs `shouldBe` fmap TestInt [1..15]
          complete `shouldBe` Right ()

makeTestStream :: (MonadIO m, MonadResource m)
               => BatchSize -> Int
               -> m (MemConnection TestInt, Stream (Of (Event TestInt)) m r)
makeTestStream batchSize n = do
  debug "makeTestStream creating partition..."
  conn <- liftIO createTestPartition
  debug $ "makeTestStream posting " <> show n <> " events..."
  mapM_ (liftIO . postTestEvent conn) [1..n]
  debug "makeTestStream returning"
  (conn,) <$> fromOne conn batchSize testStreamSource

testStreamSource :: StreamSource
testStreamSource = SomeStreams . fromList. return . StreamName $ "MemorySpec"
