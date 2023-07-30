{ config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.desktop;
in {
  config = mkIf cfg.enable {
      services.flatpak.enable = mkDefault true;
      systemd.services.flatpak-add-flathub = {
        script = ''
          exec ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        '';
        serviceConfig.Type = "oneshot";
        requires = [
          "network-online.target"
        ];
        after = [
          "network-online.target"
        ];
        wantedBy = [
          "graphical.target"
        ];
      };

      systemd.services.flatpak-workaround-cursors = { 
        script = ''
          exec ${pkgs.flatpak}/bin/flatpak override --filesystem=/usr/share/icons/:ro
        '';
        serviceConfig.Type = "oneshot";
        wantedBy = [
          "graphical.target"
        ];
      };

      system.fsPackages = [ pkgs.bindfs ];
      fileSystems =
        let mkRoSymBind = path: {
          device = path;
          fsType = "fuse.bindfs";
          options = [ "ro" "resolve-symlinks" "x-gvfs-hide" ];
        };
      in {
        "/usr/share/icons" = mkRoSymBind "/run/current-system/sw/share/icons";
      };
    }
  ;
}
