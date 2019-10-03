{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DiffsTest where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import           Data.Aeson.Diff
import           Dispenser.Diffs
import           Streaming
import           Test.Tasty.Hspec

data ExampleValue = ExampleValue
  { foo :: Text
  , bars :: [Int]
  } deriving (Eq, Generic, Ord, Read, Show)

instance FromJSON ExampleValue
instance ToJSON   ExampleValue

main :: IO ()
main = hspec allSpecs

allSpecs :: Spec
allSpecs = do
  spec_patches
  spec_patched

exampleValues :: [ExampleValue]
exampleValues =
  [ ExampleValue "foo" []
  , ExampleValue "foo" [1]
  , ExampleValue "foo" [1,2]
  , ExampleValue "bar" [1,2]
  , ExampleValue "bar" [2]
  ]

exampleStream :: Monad m => Stream (Of ExampleValue) m ()
exampleStream = S.each exampleValues

spec_patches :: Spec
spec_patches = describe "patches" $
  it "should generate correct patches" $ do
    ps :: [Patch] <- S.fst' <$> (S.toList =<< patches exampleStream)
    show ps `shouldBe` expected
    where
      expected = "[Patch {patchOperations = [Add {changePointer = Pointer {pointerPath = [OKey \"bars\",AKey 0]}, changeValue = Number 1.0}]},Patch {patchOperations = [Add {changePointer = Pointer {pointerPath = [OKey \"bars\",AKey 1]}, changeValue = Number 2.0}]},Patch {patchOperations = [Rep {changePointer = Pointer {pointerPath = [OKey \"foo\"]}, changeValue = String \"bar\"}]},Patch {patchOperations = [Rem {changePointer = Pointer {pointerPath = [OKey \"bars\",AKey 0]}}]}]" :: Text

spec_patched :: Spec
spec_patched = describe "patched" $
  it "should correctly reassemble patch streams" $ do
    ps <- patches exampleStream
    case head exampleValues of
      Nothing -> panic "unpossible!"
      Just v1 -> do
        let vstream = unsafePatched (v1, ps)
        vlist <- S.fst' <$> S.toList vstream
        vlist `shouldBe` exampleValues
