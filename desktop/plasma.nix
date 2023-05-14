{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.desktop;
  optimizeCfg = config.aviallon.optimizations;
  _sddm = pkgs.sddm.overrideAttrs (old: rec {
    pname = old.pname + "-git";
    version = "2023-05-12";
    src = pkgs.fetchFromGitHub {
      owner = "sddm";
      repo = "sddm";
      rev = "58a35178b75aada974088350f9b89db45f5c3800";
      sha256 = "sha256-lTfsMUnYu3E2L25FSrMDkh9gB5X2fC0a5rvpMnPph4k=";
    };

    patches = filter (x: hasSuffix "sddm-ignore-config-mtime.patch" x) old.patches;

    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.docutils ];

    cmakeFlags = old.cmakeFlags ++ [
      "-DBUILD_MAN_PAGES=ON"
      "-DSYSTEMD_TMPFILES_DIR=${placeholder "out"}/etc/tmpfiles.d"
      "-DSYSTEMD_SYSUSERS_DIR=${placeholder "out"}/lib/sysusers.d"
    ];

    outputs = (old.outputs or [ "out" ]) ++ [ "man" ];
  });
  sddmOptimized = optimizeCfg.optimizePkg { recursive = 0; } _sddm;
  sddmPackage = if optimizeCfg.enable then sddmOptimized else _sddm;
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

    nixpkgs.overlays = [(final: prev: { mySddm = sddmPackage; } )];

    services.xserver.displayManager.job = {
      execCmd = mkForce "exec ${sddmPackage}/bin/sddm";
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
      sddm-kcm

      libreoffice-qt

      myFirefox
    ];

    aviallon.desktop.browser.firefox.overrides.enablePlasmaBrowserIntegration = true;


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
