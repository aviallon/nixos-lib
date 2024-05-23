{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  sddmCfg = config.services.xserver.displayManager.sddm;
in {
  options.aviallon.desktop.sddm.unstable = mkEnableOption "bleeding-edge SDDM";
  options.aviallon.desktop.sddm.enable = mkEnableOption "custom SDDM configuration";

  config = mkIf cfg.sddm.enable {

    # Prevents blinking cursor
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = mkDefault true;
      wayland.compositor = "kwin";
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
        };
      };
    };
  
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

    #services.xserver.displayManager.job = mkIf config.services.xserver.displayManager.sddm.enable {
    #  execCmd = mkOverride 2 "exec ${sddmPackage}/bin/sddm";
    #};
  };
}
