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

    }
  ;
}
