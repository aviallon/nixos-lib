{
  inputs = {
    nixpkgs-22_11.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nur.url = "github:nix-community/NUR";

    fps.url = "github:wamserma/flake-programs-sqlite";
    fps.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";

    sddm-unstable = {
      url = "github:sddm/sddm/develop";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    #, flake-utils-plus
    , nixpkgs
    , nur
    , nixpkgs-unstable
    , fps
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

      specialArgs = inputs // { inherit myLib; };
    };
}
