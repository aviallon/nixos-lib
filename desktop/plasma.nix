{config, pkgs, lib, ...}:
with lib;
let
    cfg = config.aviallon.desktop;
in {
  config = mkIf cfg.enable {
    # Enable the Plasma 5 Desktop Environment.
    services.xserver.desktopManager.plasma5 = {
      enable = true;
      runUsingSystemd = true;
      useQtScaling = true;
      supportDDC = true;
    };

    systemd.tmpfiles.rules = mkAfter [
      "e ${config.users.users.sddm.home}/.cache/sddm-greeter/qmlcache/ - - - 0"
      "x ${config.users.users.sddm.home}/.cache"
    ];

    # Prevents blinking cursor
    services.xserver.displayManager.sddm = {
      enable = true;
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
        };
        X11 = {
          MinimumVT = mkOverride 50 1;
        };
      };
    };

    environment.systemPackages = with pkgs; with libsForQt5; [
      skanlite
      packagekit-qt
      discover
      akonadi
      kmail
      korganizer
      dolphin
      kio-fuse
      konsole
      kate
      yakuake
      pinentry-qt
      plasma-pa
      ark
    ];

    xdg.portal = {
      enable = mkDefault true;      
      gtkUsePortal = mkDefault true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
    };

  };
}
