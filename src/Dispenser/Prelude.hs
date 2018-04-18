{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Dispenser.Prelude
    ( module Exports
    , debug
    , sleep
    ) where

import Focus.Prelude               as Exports

import Control.Foldl               as Exports ( Fold( Fold )
                                              , FoldM( FoldM )
                                              )
import Control.Lens                as Exports ( (^.)
                                              , makeClassy
                                              , makeClassyPrisms
                                              , makeFields
                                              , makeLenses
                                              , view
                                              )
import Control.Monad.Trans.Control as Exports ( MonadBaseControl )
import Data.Aeson                  as Exports ( FromJSON
                                              , Result( Error
                                                      , Success
                                                      )
                                              , ToJSON
                                              , Value
                                              , fromJSON
                                              , toJSON
                                              )
import Data.Time.Clock             as Exports ( UTCTime )
import System.IO.Unsafe                       ( unsafePerformIO )

debugLock :: MVar ()
debugLock = unsafePerformIO $ newMVar ()
{-# NOINLINE debugLock #-}

debug :: MonadIO m => Text -> m ()
--debug s = liftIO . withMVar debugLock $ \() -> putLn $ "DEBUG: " <> s
debug = const . return $ ()

sleep :: MonadIO m => Float -> m ()
sleep n = liftIO . threadDelay . round $ n * 1000 * 1000
