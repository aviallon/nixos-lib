{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.aviallon.desktop;
  sddmCfg = config.services.displayManager.sddm;
in
{
  options.aviallon.desktop.plasma-login-manager.enable = mkEnableOption "custom Plasma configuration";

  config = {
    services.displayManager.plasma-login-manager = {
      enable = mkOverride 20 true;
      settings = { };
    };

    # Prevents blinking cursor
    systemd.services.display-manager = {
      serviceConfig = {
        Restart = mkOverride 50 "on-failure";
        TimeoutStopSec = 10;
        SendSIGHUP = true;
      };
      after = [
        "getty@tty1.service"
      ];
      conflicts = [
        "getty@tty1.service"
      ];
    };

  };
}
