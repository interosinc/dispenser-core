{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Dispenser.Diffs
     ( applyPatch
     , makePatch
     , patched
     , patches
     )  where

import           Dispenser.Prelude          hiding ( diff )
import qualified Streaming.Prelude     as S

import           Data.Aeson.Diff                   ( Patch
                                                   , diff
                                                   , patch
                                                   )
import           Dispenser.Projections             ( project
                                                   , projectM
                                                   )
import           Streaming

patched :: forall m a r. (Monad m, FromJSON a, ToJSON a)
        => (a, Stream (Of Patch) m r)
        -> Stream (Of a) m r
patched (z, xs) = project patchedFold xs
  where
    patchedFold :: Fold Patch a
    patchedFold = Fold f z identity
      where
        f :: a -> Patch -> a
        f x p = case applyPatch p x of
          Success a -> a
          Error e   -> panic $ "patched ERROR: " <> show e -- TODO

-- TODO: needs to return either r or (a, Stream ...) ? so we can have have
-- access to the zero value if it exists, to a) provide it to the user and b)
-- do things like pass it to `patched` ...
patches :: forall m a r. (Monad m, FromJSON a, ToJSON a)
        => Stream (Of a) m r ->  m (Stream (Of Patch) m r)
patches xs = S.next xs >>= \case
  Left r         -> return $ return r
  Right (z, xs') -> return $ S.drop 1 . projectM (patchFold z) $ xs'
  where
    patchFold :: a -> FoldM m a Patch
    patchFold z = FoldM f (return (z, z)) ex
      where
        f :: (a, a) -> a -> m (a, a)
        f (_, b) c = return $ (b, c)

        ex :: (a, a) -> m Patch
        ex = return . uncurry makePatch

makePatch :: ToJSON a => a -> a -> Patch
makePatch a b = diff (toJSON a) (toJSON b)

applyPatch :: (FromJSON a, ToJSON a) => Patch -> a -> Result a
applyPatch p = join . (fromJSON <$>) . patch p . toJSON
