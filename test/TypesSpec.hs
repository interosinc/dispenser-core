{-# LANGUAGE NoImplicitPrelude #-}

module TypesSpec where

import Dispenser.Prelude

import Test.Hspec
import Test.QuickCheck
import Dispenser.Types

spec :: Spec
spec = describe "should respect the" $ do

  context "monoid laws" $ do
    it "left identity"  $ property $ \x     -> x <> mempty == (x :: StreamSource)
    it "right identity" $ property $ \x     -> mempty <> x == (x :: StreamSource)
    it "semigroup law"  $ property $ \x y z ->
      x <> (y <> z) == (x <> y) <> (z :: StreamSource)
    it "mconcat law?"   $ property $ \xs ->
       mconcat xs == foldr (<>) mempty (xs :: [StreamSource])

  context "zero laws" $ do
    it "left annihilation"  $ property $ \x -> x <> zero == (zero :: StreamSource)
    it "right annihilation" $ property $ \x -> zero <> x == (zero :: StreamSource)
    it "left associative"   $ property $
      \x y z -> x <> y <> z == (x <> y) <> (z :: StreamSource)
    it "right associative"  $ property $
      \x y z -> x <> y <> z == x <> (y <> (z :: StreamSource))
