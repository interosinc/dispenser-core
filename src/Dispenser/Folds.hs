{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Dispenser.Folds
     ( currentEventValue
     , currentEventValueM
     , currentValue
     , currentValueM
     , L.generalize
     , project
     , projectM
     , projectMTVar
     ) where

import           Dispenser.Prelude
import qualified Streaming.Prelude           as S

import           Control.Concurrent.STM.TVar      ( TVar
                                                  , newTVarIO
                                                  , writeTVar
                                                  )
import qualified Control.Foldl               as L
import           Control.Monad.Trans.Control      ( liftBaseDiscard )
import           Dispenser.Types
import           Streaming

currentValue :: Monad m => Fold a b -> Stream (Of a) m r -> m b
currentValue f stream = unOf <$> L.purely S.fold f stream

currentValueM :: Monad m => FoldM m a b -> Stream (Of a) m r -> m b
currentValueM f stream = unOf <$> L.impurely S.foldM f stream

currentEventValue :: Monad m => Fold a b -> Stream (Of (Event a)) m r -> m b
currentEventValue f stream = unOf <$> L.purely S.fold f (S.map (view eventData) stream)

currentEventValueM :: Monad m => FoldM m a b -> Stream (Of (Event a)) m r -> m b
currentEventValueM f stream = unOf <$> L.impurely S.foldM f (S.map (view eventData) stream)

project :: Monad m => Fold a b -> Stream (Of a) m r -> Stream (Of b) m r
project (Fold f z ex) = S.scan f z ex

projectM :: Monad m => FoldM m a b -> Stream (Of a) m r -> Stream (Of b) m r
projectM (FoldM f z ex) = S.scanM f z ex

-- TODO: Maybe just projectMCanWriteCache where TVar is just one implementation of
--       CanWriteCache?
projectMTVar :: forall m a b r. (MonadBaseControl IO m, MonadIO m)
             => FoldM m a b -> Stream (Of a) m r -> m (TVar b)
projectMTVar f@(FoldM _ z ex) stream = do
  var <- liftIO . newTVarIO =<< ex =<< z
  -- TODO: something better than just forkIO? (at least report crashes?)
  void . liftBaseDiscard forkIO . void . S.effects . projectM (wrap' var f) $ stream
  return var
  where
    wrap' var (FoldM mf mz mex) = FoldM mf mz mex'
      where
        mex' = (g =<<) . mex
        g b = do
          liftIO . atomically $ writeTVar var b
          return b

-- TODO: X.Streaming
unOf :: Of a b -> a
unOf = fst . lazily
