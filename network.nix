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
    dns = mkOption {
      default = "systemd-resolved";
      example = "dnsmasq";
      description = "Set network DNS";
      type = types.enum [ "systemd-resolved" "dnsmasq" ];
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = (cfg.backend == "systemd-networkd");
    networking.networkmanager.enable = (cfg.backend == "NetworkManager");
    networking.dhcpcd.enable = (cfg.backend == "dhcpcd");


    services.resolved.enable = (cfg.dns == "systemd-resolved");
    services.resolved.llmnr = mkForce "false"; # https://www.blackhillsinfosec.com/how-to-disable-llmnr-why-you-want-to/

    networking.networkmanager = {
      wifi.backend = mkDefault "iwd";
      dns = mkDefault cfg.dns;
      packages = with pkgs; concatLists [
        (optional (cfg.dns == "dnsmasq") dnsmasq)
      ];
    };
    networking.wireless.enable = (cfg.backend != "NetworkManager");

    # Must always be false
    networking.useDHCP = false;

    networking.hostId = mkDefault (builtins.abort "Default hostId not changed" null);
    networking.hostName = mkDefault (builtins.abort "Default hostname not changed" null);

    networking.firewall.allowPing = !desktopCfg.enable;
  };
}
