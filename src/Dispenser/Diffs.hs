{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Dispenser.Diffs
  ( applyPatch
  , makePatch
  , unsafePatched
  , patches
  ) where

import           Dispenser.Prelude      hiding ( diff )
import qualified Streaming.Prelude as S

import           Data.Aeson.Diff               ( Patch
                                               , diff
                                               , patch
                                               )
import           Dispenser.Folds               ( project
                                               , projectM
                                               )
import           Streaming

applyPatch :: (FromJSON a, ToJSON a) => Patch -> a -> Result a
applyPatch p = (fromJSON =<<) . patch p . toJSON

makePatch :: ToJSON a => a -> a -> Patch
makePatch a b = diff (toJSON a) (toJSON b)

-- TODO: needs to return either r or (z, Stream ...) ? so we can have have
--       access to the zero value if it exists, to a) provide it to the user
--       and b) do things like pass it to `patched` ...
patches :: forall m a r. (Monad m, ToJSON a)
        => Stream (Of a) m r ->  m (Stream (Of Patch) m r)
patches xs = S.next xs >>= \case
  Right (z, xs') -> return $ S.drop 1 . projectM (FoldM f (return (z, z)) ex) $ xs'
  Left r         -> return $ return r
  where
    f :: (a, a) -> a -> m (a, a)
    f (_, b) c = return (b, c)

    ex :: (a, a) -> m Patch
    ex = return . uncurry makePatch

unsafePatched :: forall m a r. (Monad m, FromJSON a, ToJSON a)
              => (a, Stream (Of Patch) m r)
              -> Stream (Of a) m r
unsafePatched (z, xs) = project (Fold f z identity) xs
  where
    f x p = case applyPatch p x of
      Success a -> a
      Error   e -> panic $ "patched ERROR: " <> show e -- TODO: totality "finish it!"
