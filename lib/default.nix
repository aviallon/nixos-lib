{ lib ? import <nixpkgs/lib, ... }:
let
  myLib = lib.makeExtensible (self: let
    callLibs = file: import file {
      inherit lib;
      myLib = self;
    };
  in {
    math = callLibs ./math.nix;
    config = callLibs ./config.nix;
    optimizations = callLibs ./optimizations.nix;
    attrsets = callLibs ./attrsets.nix;
    types = callLibs ./types.nix;
  });
in myLib
