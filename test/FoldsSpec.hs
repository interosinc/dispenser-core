{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module FoldsSpec where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar
import qualified Data.Set                    as Set
import           Dispenser.Folds
import           Dispenser.Types
import           Streaming
import           Test.Tasty.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  projectSpec
  projectMSpec
  projectMTVarSpec
  currentEventValueSpec
  currentEventValueMSpec

projectSpec :: Spec
projectSpec = describe "project" $ do

  context "given an empty stream" $
    it "should return the correct zero value from the fold" $ do
      let stream  :: Stream (Of (Event Int)) IO () = return ()
          pStream :: Stream (Of Int) IO ()         = project sumEFold stream
      pList <- S.fst' <$> S.toList pStream
      pList `shouldBe` [0]

  context "given a non-empty stream" $
    it "should return the correct values of the fold for each event" $ do
      let stream  :: Stream (Of (Event Int)) IO () = S.each . map testEvent $ [1..3]
          pStream :: Stream (Of Int) IO ()         = project sumEFold stream
      pList <- S.fst' <$> S.toList pStream
      pList `shouldBe` [0,1,3,6]

projectMSpec :: Spec
projectMSpec = describe "projectM" $ do

  context "given an empty stream" $
    it "should return the correct zero value from the fold" $ do
      var <- newTVarIO neg100
      let stream  :: Stream (Of (Event Int)) IO () = return ()
          pStream :: Stream (Of Int) IO ()         = projectM (sumEFoldM var) stream
      pList <- S.fst' <$> S.toList pStream
      pList `shouldBe` [0]
      val <- readTVarIO var
      val `shouldBe` 10

  context "given a non-empty stream" $
    it "should return the correct values of the fold for each event" $ do
      var <- atomically $ newTVar neg100
      let stream  :: Stream (Of (Event Int)) IO () = S.each . map testEvent $ [1..3]
          pStream :: Stream (Of Int) IO ()         = projectM (sumEFoldM var) stream
      pList <- S.fst' <$> S.toList pStream
      pList `shouldBe` [0,1,3,6]
      val <- readTVarIO var
      val `shouldBe` 16

projectMTVarSpec :: Spec
projectMTVarSpec = describe "projectMTVar" $ do

  context "given an empty stream" $ do
    let stream  :: Stream (Of Int) IO () = return ()

    it "the TVar contains the zero of the projection" $ do
      var <- projectMTVar (generalize sumFold) stream
      val <- readTVarIO var
      val `shouldBe` 0

  context "given a non-empty stream" $ do
    let stream = S.each [1..3 :: Int]

    it "should return the correct values of the fold for each event" $ do
      var <- projectMTVar (generalize sumFold) stream
      sleep 0.1
      val <- readTVarIO var
      val `shouldBe` 6

currentEventValueSpec :: Spec
currentEventValueSpec = describe "currentEventValue" $ do

  context "given an empty stream" $
    it "should return the correct zero value from the fold" $ do
      let stream :: Stream (Of (Event Int)) IO () = return ()
      n <- currentEventValue sumFold stream
      n `shouldBe` 0

  context "given a non-empty stream" $
    it "should return the correct current value of the fold" $ do
      let stream :: Stream (Of (Event Int)) IO () = S.each . map testEvent $ [1..3]
      n <- currentEventValue sumFold stream
      n `shouldBe` 6

currentEventValueMSpec :: Spec
currentEventValueMSpec = describe "currentEventValueM" $ do

  context "given an empty stream" $
    it "should return the correct zero value from the fold" $ do
      var <- atomically $ newTVar neg100
      let stream :: Stream (Of (Event Int)) IO () = return ()
      n <- currentEventValueM (sumFoldM var) stream
      n `shouldBe` 0
      val <- readTVarIO var
      val `shouldBe` 10

  context "given a non-empty stream" $
    it "should return the correct current value of the fold" $ do
      var <- atomically $ newTVar neg100
      let stream  :: Stream (Of (Event Int)) IO () = S.each . map testEvent $ [1..3]
      n <- currentEventValueM (sumFoldM var) stream
      n `shouldBe` 6
      val <- readTVarIO var
      val `shouldBe` 16

testEvent :: Int -> Event Int
testEvent n = Event (EventNumber . fromIntegral $ n) Set.empty n ts
  where
    ts = panic "unused"

sumFold :: Fold Int Int
sumFold = Fold (+) 0 identity

sumFoldM :: MonadIO m => TVar Int -> FoldM m Int Int
sumFoldM var = FoldM f z ex
  where
    f acc e = let x = acc + e in writeSafePlus10 x
    z = let x = 0 in writeSafePlus10 x
    ex = return

    writeSafePlus10 x = do
      liftIO . atomically . writeTVar var $ x + 10
      return x

sumEFold :: Fold (Event Int) Int
sumEFold = Fold f z ex
  where
    f :: Int -> Event Int -> Int
    f acc e = acc + (e ^. eventData)

    z :: Int
    z  = 0

    ex :: Int -> Int
    ex = identity

sumEFoldM :: MonadIO m => TVar Int -> FoldM m (Event Int) Int
sumEFoldM var = FoldM f z ex
  where
    f acc e = do
      let x = acc + (e ^. eventData)
      liftIO . atomically . writeTVar var $ x + 10
      return x

    z = do
      let x = 0
      liftIO . atomically . writeTVar var $ x + 10
      return x

    ex = return

neg100 :: Int
neg100 = -100
