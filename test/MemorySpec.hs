{-# LANGUAGE TupleSections #-}
{-# LANGUAGE NoImplicitPrelude #-}

module MemorySpec ( main, spec ) where

import Dispenser.Prelude

import Dispenser.Types
import Test.Hspec
import qualified Streaming.Prelude                as S
import           Control.Monad.Trans.Resource
import Dispenser.Memory
import Streaming
import TestHelpers

main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "Dispenser.Memory" $ do
    forM_ (map BatchSize [1..10]) $ \batchSize -> do

      context "given a stream with 3 events in it" $ do
        let testStream = makeTestStream batchSize 3

        it "should be able to take the first 2 immediately" $ do
          stream <- S.take 2 . snd <$> runResourceT testStream
          xs <- runResourceT (S.fst' <$> S.toList stream)
          map (view eventData) xs `shouldBe` map TestInt [1..2]

        it "should be able to take 5 if two more are posted asynchronously" $ do
          (conn, stream) <- runResourceT testStream
          void . forkIO $ do
            sleep 0.05
            postTestEvent conn 4
            sleep 0.05
            postTestEvent conn 5
            sleep 0.05
            postTestEvent conn 6
          let stream' = S.take 5 stream
          xs <- runResourceT (S.fst' <$> S.toList stream')
          map (view eventData) xs `shouldBe` map TestInt [1..5]

      context "given a stream with 20 events in it" $ do
        let testStream = makeTestStream batchSize 20

        it "should be able to take all 20" $ do
          stream <- S.take 20 . snd <$> runResourceT testStream
          xs <- runResourceT (S.fst' <$> S.toList stream)
          map (view eventData) xs `shouldBe` map TestInt [1..20]

        it "should be able to take 25 if 5 are posted asynchronously" $ do
          (conn, stream) <- runResourceT testStream
          void . forkIO $ mapM_ ((sleep 0.05 >>) . postTestEvent conn) [21..25
                                                                                      ]
          let stream' = S.take 25 stream
          xs <- runResourceT (S.fst' <$> S.toList stream')
          map (view eventData) xs `shouldBe` map TestInt [1..25]

makeTestStream :: (MonadIO m, MonadResource m)
               => BatchSize -> Int
               -> m (MemConnection TestInt, Stream (Of (Event TestInt)) m r)
makeTestStream batchSize n = do
  conn <- liftIO createTestPartition
  mapM_ (liftIO . postTestEvent conn) [1..n]
  (conn,) <$> fromZero conn batchSize
