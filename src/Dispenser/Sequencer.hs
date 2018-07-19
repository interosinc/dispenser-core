{-# LANGUAGE NoImplicitPrelude #-}

module Dispenser.Sequencer where

import Dispenser.Prelude
import Dispenser.Types

resequence :: (Event a -> [Event b])
           -> (Event b -> Event b -> Ordering)
           -> [Event a] -> [Event b]
resequence f g = sortBy g . join . map f
