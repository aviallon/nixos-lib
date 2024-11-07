{config, pkgs, nixpkgs-unstable, lib, ...}:
with lib;
let
  cfg = config.aviallon.desktop;
  optimizeCfg = config.aviallon.optimizations;
in {

  imports = [
    ./plasma5.nix
    ./plasma6.nix
  ];

  config = mkIf (cfg.enable && (cfg.environment == "plasma" || cfg.environment == "plasma6" )) {
    programs.firefox.enable = true;    
    programs.firefox.policies.Extensions.Install = [ "plasma-browser-integration@kde.org" ];

    programs.chromium.extensions = [
      "cimiefiiaegbelhefglklhhakcgmhkai" # Plasma Browser Integration
    ];

    aviallon.desktop.sddm.enable = true;
    aviallon.programs.libreoffice.qt = true;

    xdg.portal.enable = mkDefault true;
    xdg.icons.enable = true;

    environment.variables = {
      ELECTRON_TRASH = "kioclient";
    };

    #environment.systemPackages = [
      #config.programs.gnupg.agent.pinentryPackage
    #];

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
