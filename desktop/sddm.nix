{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  sddmCfg = config.services.xserver.displayManager.sddm;
in {
  options.aviallon.desktop.sddm.unstable = mkEnableOption "bleeding-edge SDDM";
  options.aviallon.desktop.sddm.enable = mkEnableOption "custom SDDM configuration";

  imports = [ ./sddm-unstable.nix ];

  config = mkIf cfg.sddm.enable {

    # Delete SDDM QMLCache
    systemd.tmpfiles.rules = mkAfter [
      "e ${config.users.users.sddm.home}/.cache/sddm-greeter/qmlcache/ - - - 0"
    ];
  
    # Prevents blinking cursor
    services.xserver.displayManager.sddm = {
      enable = true;
      wayland.enable = mkDefault true;
      settings = {
        /*General.GreeterEnvironment = mkIf sddmCfg.wayland.enable (concatStringsSep "," [
          "QT_WAYLAND_SHELL_INTEGRATION=layer-shell"
          "QT_QPA_PLATFORM=wayland"
        ]);*/
        Theme = {
          CursorTheme = "breeze_cursors";
        };
        /*Wayland = mkIf sddmCfg.wayland.enable {
          CompositorCommand = mkOverride 60 "${pkgs.libsForQt5.kwin}/bin/kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1";
        };*/
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
