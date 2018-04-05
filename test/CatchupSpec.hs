{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CatchupSpec where

import Dispenser.Prelude
import Control.Concurrent.STM.TVar
import Dispenser.Catchup ( Config( Config ), make )
import Dispenser.Types
-- import Dispenser.Projections
import Streaming
import qualified Streaming.Prelude as S
import Test.Hspec

main :: IO ()
main = hspec spec

newtype TestInt = TestInt Int
  deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON  TestInt
instance ToJSON    TestInt
instance EventData TestInt

spec :: Spec
spec = describe "Catchup.make" $ do
  context "given 5 existing events with none incoming" $ do
    (_, catchup) <- runIO $ makeTestCatchup 5
    context "taking the first 5 from 0" $ do
      let newTestStream = catchup (EventNumber 0) (BatchSize 10)
      it "should find the first 5 events" $ do
        stream <- newTestStream
        events <- S.fst' <$> S.toList (S.take 5 stream)
        map (view eventData) events `shouldBe` map TestInt [1..5]
  context "given 5 existing events with 10 incoming" $ do
    (_, catchup) <- runIO $ makeTestCatchup 10
    context "taking the first 15 from 0" $ do
      let newTestStream = catchup (EventNumber 0) (BatchSize 10)
      it "should find the first 15 events" $ do
        stream <- newTestStream
        events <- S.fst' <$> S.toList (S.take 15 stream)
        map (view eventData) events `shouldBe` map TestInt [1..15]

newtype TestHandle = TestHandle (TVar TestState)

data TestState = TestState

makeTestCatchup :: Int
                -> IO ( TestHandle
                      , EventNumber -> BatchSize -> IO (Stream (Of (Event TestInt)) IO r)
                      )
makeTestCatchup startingMaxEn = do
  var <- newTVarIO TestState
  let testHandle = TestHandle var
      config :: Config IO TestInt r
      config = Config
         testCurrentEventNumber'
         testCurrentStreamFrom'
         testFromEventNumber'
         testFromNow'
         testRangeStream'
  let s = make config
  return (testHandle, s)
  where
    testCurrentEventNumber' :: MonadIO m => m EventNumber
    testCurrentEventNumber' = return . EventNumber . fromIntegral $ startingMaxEn

    testCurrentStreamFrom' :: MonadIO m
                           => EventNumber -> BatchSize -> [StreamName]
                           -> m (Stream (Of (Event TestInt)) m ())
    testCurrentStreamFrom' start@(EventNumber s) (BatchSize bs) _ =
      -- succ to shift to 1-based indexing consistent with postgres
      return . S.each $ map (f . succ) [start..end]
      where
        end = EventNumber $ s + fromIntegral bs

        f :: EventNumber -> Event TestInt
        f en@(EventNumber n) = Event en [] (TestInt . fromIntegral $ n) ts
          where
            ts = panic "ts should be unused"

    testFromEventNumber' :: (EventData a, MonadIO m)
                         => EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r)
    testFromEventNumber' = panic "testFromEventNumber' not impl"

    testFromNow' :: EventData a => [StreamName] -> m (Stream (Of (Event a)) m r)
    testFromNow' = panic "testFromNow' not impl"

    testRangeStream' :: (EventData a, MonadIO m)
                     => BatchSize -> [StreamName] -> (EventNumber, EventNumber)
                     -> m (Stream (Of (Event a)) m ())
    testRangeStream' = panic "testRangeStream' not impl"
