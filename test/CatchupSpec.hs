-- {-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
-- {-# LANGUAGE OverloadedStrings   #-}
-- {-# LANGUAGE RecordWildCards     #-}
-- {-# LANGUAGE ScopedTypeVariables #-}

module CatchupSpec where

import Dispenser.Prelude
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = describe "catchup" $
  it "should be tested" $
    pending

-- newtype TestInt = TestInt Int
--   deriving (Eq, Generic, Ord, Read, Show)

-- instance FromJSON  TestInt
-- instance ToJSON    TestInt
-- instance EventData TestInt

-- spec :: Spec
-- spec = describe "Catchup.make" $ do
--   context "given 5 existing events with none incoming" $ do
--     (_, catchup) <- runIO $ makeTestCatchup 5
--     context "taking the first 5 from 0" $ do
--       let newTestStream = catchup initialEventNumber (BatchSize 10)
--       it "should find the first 5 events" $ do
--         stream <- newTestStream
--         events <- S.fst' <$> S.toList (S.take 5 stream)
--         map (view eventData) events `shouldBe` map TestInt [1..5]
--   context "given 5 existing events with 10 incoming" $ do
--     (testHandle, catchup) <- runIO $ makeTestCatchup 5
--     runIO $ advance 10 testHandle
--     context "taking the first 15 from 0" $ do
--       let newTestStream = catchup initialEventNumber (BatchSize 10)
--       it "should find the first 15 events" $ do
--         stream <- newTestStream
--         events <- S.fst' <$> S.toList (S.take 15 stream)
--         map (view eventData) events `shouldBe` map TestInt [1..15]

-- newtype TestHandle = TestHandle { unTestHandle :: TVar TestState }

-- data TestState = TestState
--   { currentMaxEventNumber :: EventNumber
--   }

-- advance :: Word -> TestHandle -> IO ()
-- advance 0 _ = return ()
-- advance n (TestHandle var) = atomically $ modifyTVar var inc
--   where
--     inc :: TestState -> TestState
--     inc (TestState {..}) = TestState . f $ currentMaxEventNumber
--       where
--         f :: EventNumber -> EventNumber
--         f = fromJust . head . drop (fromIntegral n - 1) . iterate succ

-- newTestHandle :: EventNumber -> IO TestHandle
-- newTestHandle = (TestHandle <$>) . newTVarIO . TestState

-- handleCurrentEventNumber :: MonadIO m => TestHandle -> m EventNumber
-- handleCurrentEventNumber = (currentMaxEventNumber <$>)
--   . liftIO
--   . atomically
--   . readTVar
--   . unTestHandle

-- handleCurrentStreamFrom :: MonadIO m
--                         => TestHandle
--                         -> EventNumber -> BatchSize -> [StreamName]
--                         -> m (Stream (Of (Event TestInt)) m ())
-- handleCurrentStreamFrom testHandle start@(EventNumber s) (BatchSize bs) _ = do
--   currentMaxEventNumber' <- handleCurrentEventNumber testHandle
--   let end = max (EventNumber $ s + fromIntegral bs) currentMaxEventNumber'
--   return . S.each $ map makeTestEvent [start..end]

-- handleFromEventNumber' :: forall m r. MonadIO m
--                        => TestHandle
--                        -> EventNumber -> BatchSize -> m (Stream (Of (Event TestInt)) m r)
-- handleFromEventNumber' testHandle start@(EventNumber s) (BatchSize bs) = do
--   currentMaxEventNumber' <- handleCurrentEventNumber testHandle
--   let start' = min currentMaxEventNumber' start
--       end    = max currentMaxEventNumber' (EventNumber $ s + fromIntegral bs)
--   let existing = S.each (map makeTestEvent [start'..end])
--   return $ existing >>= const nevermore
--   where
--     nevermore :: MonadIO m => Stream (Of (Event TestInt)) m r
--     nevermore = forever . sleep $ 1000

-- makeTestEvent :: EventNumber -> Event TestInt
-- makeTestEvent en'@(EventNumber n) = Event en' [] (TestInt . fromIntegral $ n) ts
--   where
--     ts = panic "ts should be unused"

-- handleFromNow' :: MonadIO m
--                => TestHandle
--                -> [StreamName] -> m (Stream (Of (Event TestInt)) m r)
-- handleFromNow' testHandle _streamNames = do
--   currentMaxEventNumber' <- liftIO $ handleCurrentEventNumber testHandle
--   handleFromEventNumber' testHandle currentMaxEventNumber' (BatchSize 10)

-- handleRangeStream' :: MonadIO m
--                    => TestHandle
--                    -> BatchSize -> [StreamName] -> (EventNumber, EventNumber)
--                    -> m (Stream (Of (Event TestInt)) m ())
-- handleRangeStream' testHandle (BatchSize bs) _streamNames (minE, maxE) = do
--   currentMaxEventNumber' <- liftIO $ handleCurrentEventNumber testHandle
--   let start = min currentMaxEventNumber' minE
--       end   = max currentMaxEventNumber' maxE
--   return . S.take (fromIntegral bs) . S.each $ (map makeTestEvent [start..end])

-- makeTestCatchup :: Int
--                 -> IO ( TestHandle
--                       , EventNumber -> BatchSize -> IO (Stream (Of (Event TestInt)) IO r)
--                       )
-- makeTestCatchup current = do
--   testHandle <- newTestHandle (EventNumber . fromIntegral $ current)
--   let config :: Config IO TestInt r
--       config = Config
--          (handleCurrentEventNumber testHandle)
--          (handleCurrentStreamFrom testHandle)
--          (handleFromEventNumber' testHandle)
--          (handleFromNow' testHandle)
--          (handleRangeStream' testHandle)
--   return (testHandle, make config)
