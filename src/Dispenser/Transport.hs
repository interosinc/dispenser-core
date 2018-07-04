{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Dispenser.Transport
     ( ConstTransport( ConstTransport )
     , NullTransport( NullTransport )
     , Selector
     , Transport
     , subscribe
     , unSelector
     ) where

import           Dispenser.Prelude      hiding ( Selector )
import qualified Streaming.Prelude as S

import           Streaming

newtype Selector s a = Selector { unSelector :: s }
  deriving (Data, Eq, Ord, Read, Show)

class Transport t s a where
  subscribe :: MonadIO m => t -> Selector s a  -> m (Stream (Of a) m r)

data NullTransport s a = NullTransport

instance Transport (NullTransport s a) s a where
  subscribe _ _ = forever $ sleep 10000

newtype ConstTransport s a = ConstTransport { constValue :: a }

instance Transport (ConstTransport s a) s a where
  subscribe transp sel = do
    next <- subscribe transp sel
    return $ stream >> next
    where
      stream :: Monad m => Stream (Of a) m ()
      stream = S.yield (constValue transp)
