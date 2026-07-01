{
  config,
  pkgs,
  options,
  lib,
  myLib,
  ...
}:
with lib;
let
  cfg = config.aviallon.overlays;
in {

  imports = [
    (mkRenamedOptionModule
      [ "aviallon" "overlays" "optimizations" ]
      [ "aviallon" "optimizations" "enable" ]
    )
    (mkRemovedOptionModule
      [ "aviallon" "overlays" "traceCallPackage" ]
      "removed as it was debug only and not properly tested"
    )
  ];

  options.aviallon.overlays = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Wether to enable system-wide overlays or not";
      type = types.bool;
    };
  };
  
  config = mkIf cfg.enable {
    nix.nixPath =
      # Append our nixpkgs-overlays.
      [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ];

    nixpkgs.overlays = [
        (final: prev: {
          htop = prev.htop.overrideAttrs (old: {
            configureFlags =
              (filter (c: c != "--enable-affinity" ) old.configureFlags)
              ++ [ "--enable-hwloc" ];

            nativeBuildInputs =
              old.nativeBuildInputs
              ++ [ final.pkg-config (getDev final.hwloc) ];

            buildInputs =
              old.buildInputs
              ++ [ (getLib final.hwloc) ];
          });
          
          ark = prev.ark.override {
            unfreeEnableUnrar = true;
          };
        })
        # (final: prev: {
        #  # linux-manual requires scripts/split-man.pl from the kernel source, but
        #  # neither xanmod 6.19.7 nor vanilla 6.18.x ship it yet.
        #   linux-manual = prev.linux-manual.override { kernel = config.boot.kernelPackages.kernel; }
        # })
    ];
    
    aviallon.programs.allowUnfreeList = [
      "unrar"
      "ark"
    ];
  };
}
