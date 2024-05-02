{lib, myLib, ...}:
with lib;
rec {
  isBroken = x:
    let
      tryX = builtins.tryEval x;
    in
      if
        tryX.success && (isDerivation tryX.value)
      then
        tryX.value.meta.insecure || tryX.value.meta.broken
      else   
        true
    ;
}
