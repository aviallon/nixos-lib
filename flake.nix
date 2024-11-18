{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nur.url = "github:nix-community/NUR";
    suyu = {
      url = "github:Noodlez1232/suyu-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.flake-utils.follows = "flake-utils";
    };

    fps.url = "github:wamserma/flake-programs-sqlite";
    fps.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , nur
    , nixpkgs-unstable
    , fps
    , suyu
    , ...
    }: let
      lib = nixpkgs.lib;
      myLib = import ./lib {
        inherit lib;
      };
      mkPkgs = pkgs: { system ? system
                     , config
                     , overlays ? [ ]
                     , ...
                     }: import pkgs { inherit system config overlays; };
    in {
      inherit self inputs myLib;

      overlays.default = final: prev:
        self.overlay
          final
          (nur.overlay final prev)
        ;

      overlay = (final: prev: {});

      nixosModules = rec {
        aviallon = import ./default.nix;
        default = aviallon;
      };

      nixpkgsConfig = self.nixosModules.aviallon.aviallon.programs.config;

      specialArgs = inputs // { inherit myLib; };
    };
}
