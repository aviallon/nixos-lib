{config, pkgs, lib, ...}:
with lib;
let
    cfg = config.aviallon.desktop;
in {
    config = mkIf (cfg.enable && (cfg.environment == "gnome")) {
        services.xserver.desktopManager.gnome = {
            enable = true;
        };
        services.xserver.displayManager.gdm = {
            enable = true;
        };

        services.gnome = {
            sushi.enable = true;
            tracker.enable = true;
            tracker-miners.enable = true;
            core-shell.enable = true;
            gnome-keyring.enable = true;
            glib-networking.enable = true;
            gnome-user-share.enable = true;
            core-os-services.enable = true;
            gnome-remote-desktop.enable = true;
            gnome-online-miners.enable = true;
            gnome-initial-setup.enable = true;
            gnome-settings-daemon.enable = true;
            gnome-online-accounts.enable = true;
            gnome-browser-connector.enable = true;
        };

        qt5.platformTheme = "gnome"; # Force Gnome theme for better UX

        xdg.portal = {
            enable = mkDefault true;
        };

        programs.chromium.extensions = [
          "gphhapmejobijbbhgpjhcjognlahblep" # Gnome Shell integration
        ];

        environment.systemPackages = with pkgs; []
          ++ [
            guake
          ]
          ++ (with gnome; [
            gnome-software
          ])
          ++ (with gnomeExtensions; [
            gamemode
            dash-to-dock
            dash-to-dock-toggle
            dash-to-dock-animator
            tray-icons-reloaded
          ])
        ;
        systemd.packages = with pkgs; [
          gnomeExtensions.gamemode
          gnomeExtensions.dash-to-dock
          gnomeExtensions.dash-to-dock-animator
          gnomeExtensions.dash-to-dock-toggle
          gnomeExtensions.tray-icons-reloaded
        ];
    };
}
