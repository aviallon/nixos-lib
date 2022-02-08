{config, pkgs, options, lib, ...}:
with lib;
let
  cfg = config.aviallon.overlays;
in
{
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
      # Prepend default nixPath values.
      options.nix.nixPath.default ++
      # Append our nixpkgs-overlays.
      [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ]
    ;


    nixpkgs.overlays = [
    #  (self: super: {
    #    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
    #      inherit pkgs;
    #    };
    #  })
    ];
  }; 
}
