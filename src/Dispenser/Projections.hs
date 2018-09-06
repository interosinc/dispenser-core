{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Dispenser.Projections
  ( Projection(..)
  , ProjectionM(..)
  , adhocStream
  , adhocStreamM
  , adhocValue
  , adhocValueM
  ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude as S

import           Control.Foldl          ( Fold )
import           Dispenser.Folds
import           Streaming

data Projection p e s v = Projection
  { pfold   :: p -> Fold e s
  , extract :: s -> v
  }

data ProjectionM m p e s v = ProjectionM
  { pfoldM   :: p -> FoldM m e s
  , extractM :: s -> m v
  }

adhocStream :: forall m p e s v r. Monad m
            => Projection p e s v
            -> p
            -> Stream (Of e) m r
            -> Stream (Of v) m r
adhocStream proj p = S.map (extract proj) . project (pfold proj p)

adhocValue :: forall m p e s v r. Monad m
           => Projection p e s v
           -> p
           -> Stream (Of e) m r
           -> m v
adhocValue proj p es = extract proj <$> currentValue (pfold proj p) es

adhocStreamM :: forall m p e s v r. Monad m
             => ProjectionM m p e s v
             -> p
             -> Stream (Of e) m r
             -> Stream (Of v) m r
adhocStreamM projM p = S.mapM (extractM projM) . projectM (pfoldM projM p)

adhocValueM :: forall m p e s v r. Monad m
            => ProjectionM m p e s v
            -> p
            -> Stream (Of e) m r
            -> m v
adhocValueM projM p es = extractM projM =<< currentValueM (pfoldM projM p) es
