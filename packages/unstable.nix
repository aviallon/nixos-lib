{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.overlays;
  hardwareCfg = config.aviallon.hardware;
  unstable = import (fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    ref = "nixos-unstable";
  }) {
    config = config.nixpkgs.config // { allowUnfree = true; } ;
    overlays = config.nixpkgs.overlays;
  };
  nur = import (fetchGit {
    url = "https://github.com/nix-community/NUR.git";
    ref = "master";
  }) {
    inherit pkgs;
  };
in {
  config = {
    nixpkgs.overlays = mkBefore ([]
      ++ [(final: prev: {
        inherit nur;
        inherit unstable;
      })]
    );
  };
}
