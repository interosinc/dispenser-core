{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE NoImplicitPrelude #-}

module FunctionsSpec where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import qualified Data.Set          as Set
import           Data.Time.Clock          ( UTCTime( UTCTime )
                                          , addUTCTime
                                          )
import           Dispenser
import           Test.Hspec

data EventA = EventA Int
  deriving (Eq, Generic, Ord, Read, Show)

data EventB = EventB Char
  deriving (Eq, Generic, Ord, Read, Show)

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  let eventStream = S.each . take 5 . map eventize

  describe "mergeEventStreams" $ do
    it "should merge correctly" $ do
      let streamA = eventStream . zip [0,2..] . map EventA $ [1..]
          streamB = eventStream . zip [1,3..] . map EventB $ ['a'..]
      resultA <- S.toList_ streamA
      resultB <- S.toList_ streamB
      resultC <- S.toList_ $ mergeEventStreams Left Right streamA streamB
      resultC `shouldBe` mergeLists resultA resultB

  describe "mergeSameEventStreams" $ do
    it "should merge correctly" $ do
      let streamA = eventStream . zip [0,2..] . map EventA $ [1..]
          streamB = eventStream . zip [1,3..] . map EventA $ [1..]
      resultA <- S.toList_ streamA
      resultB <- S.toList_ streamB
      resultC <- S.toList_ $ mergeSameEventStreams streamA streamB
      resultC `shouldBe` mergeSameLists resultA resultB

mergeLists :: [Event a]
           -> [Event b]
           -> [Event (Either a b)]
mergeLists = go
  where
    go xs [] = fmap f xs
    go [] ys = fmap g ys
    go (x:xs) (y:ys) = f x:g y:mergeLists xs ys

    f = fmap Left
    g = fmap Right

mergeSameLists :: [Event a]
               -> [Event a]
               -> [Event a]
mergeSameLists = go
  where
    go xs [] = xs
    go [] ys = ys
    go (x:xs) (y:ys) = x:y:mergeSameLists xs ys

eventize :: (Integer, a) -> Event a
eventize (n, x) = Event (EventNumber n) Set.empty x (Timestamp ts')
  where
    ts  = UTCTime (toEnum 0) (toEnum 0)
    ndt = fromInteger n
    ts' = addUTCTime ndt ts
