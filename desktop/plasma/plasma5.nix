{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generic = import ./generic.nix {
    kdePackages = pkgs.libsForQt5;
  };
in {
  config = mkIf (cfg.enable && (cfg.environment == "plasma")) {
    # Enable the Plasma 5 Desktop Environment.
    services.xserver.desktopManager.plasma5 = {
      enable = true;
      runUsingSystemd = true;
      useQtScaling = true;

      # Removed in: https://github.com/NixOS/nixpkgs/pull/172078
      # and: https://github.com/NixOS/nixpkgs/pull/221721
      # Once this (https://invent.kde.org/plasma/powerdevil/-/issues/19) is solved, make PR to add it back (prehaps by default?)
      # supportDDC = true;
    };

    environment.systemPackages = generic.commonPackages ++ [
      pkgs.kio-fuse
    ];

    # We prefer Plasma Wayland
    services.displayManager.defaultSession = "plasmawayland";
  };
}
