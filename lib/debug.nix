{ lib, myLib }:
with lib;
rec {
  toPretty = depth: x:
    # Stolen from: https://github.com/teto/nixpkgs/blob/6f098631f6f06b93c17f49abdf677790e017778d/lib/debug.nix#L109C5-L117C30
    let
        snip = v: if      isList  v then noQuotes "[…]" v
                  else if isAttrs v then noQuotes "{…}" v
                  else v;
        noQuotes = str: v: { __pretty = const str; val = v; };
        modify = n: fn: v: if (n == 0) then fn v
                      else if isList  v then map (modify (n - 1) fn) v
                      else if isAttrs v then mapAttrs
                        (const (modify (n - 1) fn)) v
                      else v;
    in lib.generators.toPretty { allowPrettyValues = true; } (modify depth snip x);
      
  traceValWithPrefix = prefix: value:
    #trace "traceValWithPrefix 'prefix': ${prefix}" value
    trace "${prefix}: ${toPretty 2 value}" value
  ;
}
