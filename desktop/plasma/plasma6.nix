{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generic = import ./generic.nix {
    kdePackages = pkgs.kdePackages;
  };
in {
  config = mkIf (cfg.enable && (cfg.environment == "plasma6")) {
    # Enable the Plasma 6 Desktop Environment.
    services.desktopManager.plasma6 = {
      enable = true;
    };

    environment.systemPackages = generic.commonPackages;

    # We prefer Plasma Wayland
    services.displayManager.defaultSession = "plasma";
  };
}
