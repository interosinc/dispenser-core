{ mkDerivation, aeson, aeson-diff, base, bytestring, containers
, data-default, foldl, hspec, lens, monad-control, protolude
, QuickCheck, quickcheck-instances, random, resourcet, stdenv, stm
, streaming, text, time, unordered-containers, zero
, ...
}:
mkDerivation {
  pname = "dispenser-core";
  version = "0.2.0.0";
  src = ./.;
  libraryHaskellDepends = [
    aeson aeson-diff base bytestring containers data-default foldl lens
    monad-control protolude QuickCheck quickcheck-instances random
    resourcet stm streaming text time unordered-containers zero
  ];
  testHaskellDepends = [
    aeson aeson-diff base bytestring containers data-default foldl
    hspec lens monad-control protolude QuickCheck quickcheck-instances
    random resourcet stm streaming text time unordered-containers zero
  ];
  homepage = "https://github.com/superpowerscorp/dispenser-core#readme";
  license = stdenv.lib.licenses.bsd3;
}
