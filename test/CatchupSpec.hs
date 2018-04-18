{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CatchupSpec where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import           Data.Maybe                       ( fromJust )
import           Dispenser.Catchup                ( Config( Config )
                                                  , make
                                                  )
import           Dispenser.Types
import           Streaming
import           Test.Hspec

-- import Dispenser.Projections

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
      let newTestStream = catchup initialEventNumber (BatchSize 10)
      it "should find the first 5 events" $ do
        stream <- newTestStream
        events <- S.fst' <$> S.toList (S.take 5 stream)
        map (view eventData) events `shouldBe` map TestInt [1..5]
  context "given 5 existing events with 10 incoming" $ do
    (testHandle, catchup) <- runIO $ makeTestCatchup 5
    runIO $ advance 10 testHandle
    context "taking the first 15 from 0" $ do
      let newTestStream = catchup initialEventNumber (BatchSize 10)
      it "should find the first 15 events" $ do
        stream <- newTestStream
        events <- S.fst' <$> S.toList (S.take 15 stream)
        map (view eventData) events `shouldBe` map TestInt [1..15]

newtype TestHandle = TestHandle { unTestHandle :: TVar TestState }

data TestState = TestState
  { currentMaxEventNumber :: EventNumber
  }

advance :: Word -> TestHandle -> IO ()
advance 0 _ = return ()
advance n (TestHandle var) = atomically $ modifyTVar var inc
  where
    inc :: TestState -> TestState
    inc (TestState {..}) = TestState . f $ currentMaxEventNumber
      where
        f :: EventNumber -> EventNumber
        f = fromJust . head . drop (fromIntegral n - 1) . iterate succ

newTestHandle :: EventNumber -> IO TestHandle
newTestHandle = (TestHandle <$>) . newTVarIO . TestState

handleCurrentEventNumber :: MonadIO m => TestHandle -> m EventNumber
handleCurrentEventNumber = (currentMaxEventNumber <$>)
  . liftIO
  . atomically
  . readTVar
  . unTestHandle

handleCurrentStreamFrom :: MonadIO m
                        => TestHandle
                        -> EventNumber -> BatchSize -> [StreamName]
                        -> m (Stream (Of (Event TestInt)) m ())
handleCurrentStreamFrom testHandle start@(EventNumber s) (BatchSize bs) _ = do
  currentMaxEventNumber' <- handleCurrentEventNumber testHandle
  let end = max (EventNumber $ s + fromIntegral bs) currentMaxEventNumber'
  -- succ to shift to 1-based indexing consistent with postgres
  return . S.each $ map (f . succ) [start..end]
  where
    f :: EventNumber -> Event TestInt
    f en@(EventNumber n) = Event en [] (TestInt . fromIntegral $ n) ts
      where
        ts = panic "ts should be unused"

handleFromEventNumber' :: (EventData a, MonadIO m)
                       => TestHandle
                       -> EventNumber -> BatchSize -> m (Stream (Of (Event a)) m r)
handleFromEventNumber' = panic "handleFromEventNumber' not impl"

handleFromNow' :: EventData a
               => TestHandle
               -> [StreamName] -> m (Stream (Of (Event a)) m r)
handleFromNow' = panic "handleFromNow' not impl"

handleRangeStream' :: (EventData a, MonadIO m)
                   => TestHandle
                   -> BatchSize -> [StreamName] -> (EventNumber, EventNumber)
                   -> m (Stream (Of (Event a)) m ())
handleRangeStream' = panic "handleRangeStream' not impl"

makeTestCatchup :: Int
                -> IO ( TestHandle
                      , EventNumber -> BatchSize -> IO (Stream (Of (Event TestInt)) IO r)
                      )
makeTestCatchup current = do
  testHandle <- newTestHandle (EventNumber . fromIntegral $ current)
  let config :: Config IO TestInt r
      config = Config
         (handleCurrentEventNumber testHandle)
         (handleCurrentStreamFrom testHandle)
         (handleFromEventNumber' testHandle)
         (handleFromNow' testHandle)
         (handleRangeStream' testHandle)
  return (testHandle, make config)
