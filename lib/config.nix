{lib, myLib}:
with lib;
let
  mkListToString = { sep ? " " }: list: concatStringsSep sep (
    forEach list (v: toString v)
  );
in rec {
  mkValueString =
    let
      gen = generators.mkValueStringDefault {};
      listToString = mkListToString {};
    in v: if isList v then listToString v
          else gen v;
  
  mkKeyValue = { sep }: with generators; toKeyValue {
    mkKeyValue = mkKeyValueDefault {
      mkValueString = mkValueString;
    } sep;
  };

  toSystemd = mkKeyValue {
    sep = "=";
  };
  toNix = mkKeyValue {
    sep = " = ";
  };
}
