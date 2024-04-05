{config, pkgs, lib, sddm-unstable, ...}:
with lib;
let
  cfg = config.aviallon.desktop;
  optimizeCfg = config.aviallon.optimizations;
  _sddm = if cfg.sddm.unstable then pkgs.unstable.sddm else pkgs.sddm;
  sddmOptimized = optimizeCfg.optimizePkg { recursive = 0; } _sddm;
  sddmPackage = if optimizeCfg.enable then sddmOptimized else _sddm;
in {
  options.aviallon.desktop.sddm.unstable = mkEnableOption (mdDoc "bleeding-edge SDDM");

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

    systemd.tmpfiles.rules = mkAfter [
      "e ${config.users.users.sddm.home}/.cache/sddm-greeter/qmlcache/ - - - 0"
      "x ${config.users.users.sddm.home}/.cache"
    ];
    programs.firefox.enable = true;

    # Already brought in by ${nixpkgs}/nixos/modules/services/x11/desktop-managers/plasma5.nix
    # programs.firefox.nativeMessagingHosts.packages = [ pkgs.libsForQt5.plasma-browser-integration ];
    
    programs.firefox.policies.Extensions.Install = [ "plasma-browser-integration@kde.org" ];

    environment.etc = {
      "chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json".source = 
        "${pkgs.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
    };

    programs.chromium.extensions = [
      "cimiefiiaegbelhefglklhhakcgmhkai" # Plasma Browser Integration
    ];

    # Prevents blinking cursor
    services.xserver.displayManager.sddm = {
      enable = true;
      wayland.enable = mkDefault true;
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
        };
        X11 = {
          MinimumVT = mkOverride 50 1;
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

    nixpkgs.overlays = [(final: prev: { mySddm = sddmPackage; } )];

    services.xserver.displayManager.job = {
      execCmd = mkOverride 2 "exec ${sddmPackage}/bin/sddm";
    };


    environment.systemPackages = with pkgs; with libsForQt5; [
      skanpage
      packagekit-qt
      discover
      akonadi
      kmail
      kdepim-addons
      kdepim-runtime
      
      korganizer
      kalendar
      dolphin
      kio-fuse
      konsole
      kate
      yakuake
      pinentry-qt
      plasma-pa
      ark
      kolourpaint
      krdc
      sddm-kcm
    ];

    aviallon.programs.libreoffice.qt = true;

    xdg.portal.enable = mkDefault true;
    xdg.icons.enable = true;

    systemd.user.services.setup-xdg-cursors = mkIf config.xdg.icons.enable {
      script = ''
          [ -d "$HOME/.icons/default" ] || mkdir -p "$HOME/.icons/default"
          cat >"$HOME/.icons/default/index.theme" <<EOF
          [icon theme]
          Inherits=''${XCURSOR_THEME:-breeze_cursors}
          EOF
          '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      wantedBy = [ "graphical-session-pre.target" ];
      partOf = [ "graphical-session-pre.target" ];
    };

  };
}
