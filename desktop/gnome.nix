{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
    cfg = config.aviallon.desktop;
in {
    config = mkIf (cfg.enable && (cfg.environment == "gnome")) {
        services.desktopManager.gnome = {
            enable = true;
        };
        services.displayManager.gdm = {
            enable = true;
        };

        services.gnome = {
            sushi.enable = true;
            core-shell.enable = true;
            /* Also enables: 
             * - glib-networking
             * - gnome-browser-connector
             * - gnome-initial-setup
             * - gnome-remote-desktop
             * - gnome-settings-daemon
             * - gnome-user-share
             * - rygel
             */  
            core-os-services.enable = true;
            /* Also enables:
             * - gnome-keyring
             * - gnome-online-accounts
             * - gnome-online-miner
             * - tracker-miners
             * - tracker
             */
        };

        qt.platformTheme = "gnome"; # Force Gnome theme for better UX

        xdg.portal = {
            enable = mkDefault true;
        };

        programs.chromium.extensions = [
          "gphhapmejobijbbhgpjhcjognlahblep" # Gnome Shell integration
        ];

        programs.firefox.enable = true;

        aviallon.programs.libreoffice.enable = true;

        environment.systemPackages = with pkgs; [ guake gnome-software ]
          ++ (with gnomeExtensions; [
            gamemode-shell-extension
            dash-to-dock
            tray-icons-reloaded
          ])
        ;
        systemd.packages = with pkgs; [
          gnomeExtensions.gamemode-shell-extension
          gnomeExtensions.dash-to-dock
          gnomeExtensions.tray-icons-reloaded
        ];
    };
}
