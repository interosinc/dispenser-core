{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Dispenser.Prelude
    ( module Exports
    , debug
    , toggleDebug
    , sleep
    ) where

import Focus.Prelude                as Exports

import Control.Concurrent.STM.TVar             ( TVar
                                               , modifyTVar
                                               , newTVarIO
                                               , readTVar
                                               )
import Control.Foldl                as Exports ( Fold( Fold )
                                               , FoldM( FoldM )
                                               )
import Control.Lens                 as Exports ( (^.)
                                               , makeClassy
                                               , makeClassyPrisms
                                               , makeFields
                                               , makeLenses
                                               , view
                                               )
import Control.Monad.Trans.Control  as Exports ( MonadBaseControl )
import Control.Monad.Trans.Resource as Exports ( runResourceT )
import Data.Aeson                   as Exports ( FromJSON
                                               , Result( Error
                                                       , Success
                                                       )
                                               , ToJSON
                                               , Value
                                               , fromJSON
                                               , toJSON
                                               )
import Data.Time.Clock              as Exports ( UTCTime )
import System.IO.Unsafe                        ( unsafePerformIO )

debugLock :: MVar ()
debugLock = unsafePerformIO $ newMVar ()
{-# NOINLINE debugLock #-}

debugState :: TVar Bool
debugState = unsafePerformIO $ newTVarIO False
{-# NOINLINE debugState #-}

-- TODO: switch back to an approach that doesn't require a tvar hit on every invocation
debug :: MonadIO m => Text -> m ()
debug s = liftIO $
  (atomically . readTVar $ debugState) >>= \enabled ->
    when enabled $ withMVar debugLock $ \() -> putLn $ "DEBUG: " <> s

toggleDebug :: IO ()
toggleDebug = atomically $ modifyTVar debugState not

sleep :: MonadIO m => Float -> m ()
sleep n = liftIO . threadDelay . round $ n * 1000 * 1000
