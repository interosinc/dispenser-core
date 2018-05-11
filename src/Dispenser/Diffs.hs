{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Dispenser.Diffs where

import Dispenser.Prelude

import Data.Generic.Diff ( EditScript )
import Streaming

data TempData = TempData
  { _tempDataName :: Text
  , _tempDataTags :: [Text]
  } deriving (Eq, Generic, Ord, Read, Show)


edits :: Stream (Of a) m r -> Stream (Of (EditScript f x y)) m r
edits = undefined

temp :: IO ()
temp = print diff_1_2
  where
    td1 = TempData "Before" []
    td2 = TempData "After"  ["changed"]
    diff_1_2 = diff td1 td2
    td3 = TempData "Before" ["tagged"]
    td4 = TempData "After"  ["tagged", "changed"]
