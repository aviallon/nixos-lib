{ lib, myLib }:
with lib;
{
  package' = types.package // {
    merge = loc: defs:
      let res = mergeDefaultOption loc defs;
      in if builtins.isPath res || (builtins.isString res && ! builtins.hasContext res)
        then toDerivation res
        else res;
  };
}
