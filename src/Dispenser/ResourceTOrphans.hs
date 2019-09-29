{-# LANGUAGE FlexibleContexts              #-}
{-# LANGUAGE FlexibleInstances             #-}
{-# LANGUAGE MultiParamTypeClasses         #-}
{-# LANGUAGE NoImplicitPrelude             #-}
{-# LANGUAGE TypeFamilies                  #-}
{-# LANGUAGE UndecidableInstances          #-}
{-# OPTIONS_GHC -Wno-orphans               #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

module Dispenser.ResourceTOrphans where

import Dispenser.Prelude

import Control.Monad.Base                    ( MonadBase
                                             , liftBase
                                             , liftBaseDefault
                                             )
import Control.Monad.Trans.Control           ( ComposeSt
                                             , MonadTransControl
                                             , StM
                                             , StT
                                             , defaultLiftBaseWith
                                             , defaultRestoreM
                                             , liftBaseWith
                                             , liftWith
                                             , restoreM
                                             , restoreT
                                             )
import Control.Monad.Trans.Resource.Internal ( ResourceT( ResourceT )
                                             , unResourceT
                                             )

instance MonadBase IO m => MonadBase IO (ResourceT m) where
 liftBase = liftBaseDefault

instance MonadBaseControl IO m => MonadBaseControl IO (ResourceT m) where
  type StM (ResourceT m) a = ComposeSt ResourceT m a
  liftBaseWith = defaultLiftBaseWith
  restoreM     = defaultRestoreM
  {-# INLINABLE liftBaseWith #-}
  {-# INLINABLE restoreM #-}

instance MonadTransControl ResourceT where
  type StT ResourceT a = a
  liftWith f = ResourceT $ \r -> f $ \t -> unResourceT t r
  restoreT = ResourceT . const
  {-# INLINABLE liftWith #-}
  {-# INLINABLE restoreT #-}
