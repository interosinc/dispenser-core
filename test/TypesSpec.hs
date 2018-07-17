{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module TypesSpec where

import Dispenser.Prelude

import Dispenser.Types
import Test.Hspec
import Test.QuickCheck

spec :: Spec
spec = describe "StreamSource should respect the" $ do

  context "monoid laws" $ do

    it "left identity"  . property $                     \(x :: StreamSource) ->

      x <> mempty == x

    it "right identity" . property $                     \(x :: StreamSource) ->

      mempty <> x == x

    it "semigroup law"  . property $                     \x y (z :: StreamSource) ->

      x <> (y <> z) == (x <> y) <> z

    it "mconcat law?"   . property $                     \(xs :: [StreamSource]) ->

      mconcat xs == foldr (<>) mempty xs

  context "zero laws" $ do

    it "left annihilation"  . property $                 \(x :: StreamSource) ->

      x <> zero == zero

    it "right annihilation" . property $                 \(x :: StreamSource) ->

      zero <> x == zero

    it "left associative"   . property $                 \x y (z :: StreamSource) ->

      x <> y <> z == (x <> y) <> z

    it "right associative"  . property $                 \x y (z :: StreamSource) ->

      x <> y <> z == x <> (y <> z)
