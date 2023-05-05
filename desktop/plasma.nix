{config, pkgs, lib, ...}:
with lib;
let
    cfg = config.aviallon.desktop;
in {
  config = mkIf (cfg.enable && (cfg.environment == "plasma")) {
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
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
        };
        X11 = {
          MinimumVT = mkOverride 50 1;
        };
        General = {
          DisplayServer = "wayland";
        };
      };
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

      (myFirefox.override { enablePlasmaBrowserIntegration = true; })
    ];

    environment.profileRelativeSessionVariables = {
      QT_PLUGIN_PATH = mkForce []; # Remove as it causes many issues when pulling one package from nixos-unstable
    };

    xdg.portal = {
      enable = mkDefault true;
    };

  };
}
