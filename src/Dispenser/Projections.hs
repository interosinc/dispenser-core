{-# LANGUAGE NoImplicitPrelude #-}

module Dispenser.Projections
     ( currentValue
     , currentValueM
     , project
     , projectM
     ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import qualified Control.Foldl     as L
import           Dispenser.Types
import           Streaming

project :: Monad m => Fold a b -> Stream (Of a) m r -> Stream (Of b) m r
project (Fold f z ex) = S.scan f z ex

projectM :: Monad m => FoldM m a b -> Stream (Of a) m r -> Stream (Of b) m r
projectM (FoldM f z ex) = S.scanM f z ex

currentValue :: Monad m
             => Fold a b -> Stream (Of (Event a)) m r -> m b
currentValue f inStream = do
  let stream = S.map (view eventData) inStream
  x :> _ <- L.purely S.fold f stream
  return x

currentValueM :: Monad m
              => FoldM m a b -> Stream (Of (Event a)) m r -> m b
currentValueM f inStream = do
  let stream = S.map (view eventData) inStream
  x :> _ <- L.impurely S.foldM f stream
  return x
