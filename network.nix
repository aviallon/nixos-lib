{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.network;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.network = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's network tuning";
      type = types.bool;
    };
    backend = mkOption {
      default = "systemd-networkd";
      example = "NetworkManager";
      description = "Set network backend";
      type = types.enum [ "systemd-networkd" "NetworkManager" "dhcpcd" ];
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = (cfg.backend == "systemd-networkd");
    networking.networkmanager.enable = (cfg.backend == "NetworkManager");
    networking.dhcpcd.enable = (cfg.backend == "dhcpcd");

#    networking.networkmanager.wifi.backend = mkDefault "iwd";
    networking.wireless.enable = (cfg.backend != "NetworkManager");

    # Must always be false
    networking.useDHCP = false;

    networking.hostId = mkDefault (builtins.abort "Default hostId not changed" null);
    networking.hostName = mkDefault (builtins.abort "Default hostname not changed" null);

    networking.firewall.allowPing = !desktopCfg.enable;
  };
}
