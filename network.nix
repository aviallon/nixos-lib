{ config, pkgs, lib, myLib, ... }:
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
      type = types.enum [ "systemd-resolved" "dnsmasq" "unbound" "none" "default" ];
    };
    vpnSupport = mkEnableOption "VPN support of many kinds in NetworkManager" // { default = desktopCfg.enable; };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = (cfg.backend == "systemd-networkd");
    networking.networkmanager.enable = (cfg.backend == "NetworkManager");
    networking.dhcpcd.enable = (cfg.backend == "dhcpcd");


    services.resolved = {
      enable = (cfg.dns == "systemd-resolved");
      llmnr = mkForce "false"; # https://www.blackhillsinfosec.com/how-to-disable-llmnr-why-you-want-to/
      dnssec = "false"; # Causes issues with masquerading DNS
      extraConfig = myLib.config.toSystemd {
        "DNS" = [
          # cloudflare-dns.com
          "1.1.1.1"
          "2606:4700:4700::1111"
          "1.0.0.1"
          "2606:4700:4700::1001"
        ];
      };
    };

    services.udev.extraRules = concatStringsSep "\n" [
      (optionalString (!config.aviallon.laptop.enable) ''
      ACTION=="add", SUBSYSTEM=="net", NAME=="enp*", RUN+="${pkgs.ethtool}/bin/ethtool -s $name wol gu"
      '')
    ];

    services.unbound.enable = (cfg.dns == "unbound");

    networking.networkmanager = {
      wifi.backend = mkDefault "iwd";
      dns = mkDefault cfg.dns;
      plugins = with pkgs; []
        ++ optional (cfg.dns == "dnsmasq") dnsmasq
        ++ optionals cfg.vpnSupport [
          networkmanager_strongswan
          networkmanager-openvpn
          networkmanager-openconnect
          networkmanager-sstp
          networkmanager-l2tp
        ]
      ;
    };
    networking.wireless.enable = (cfg.backend != "NetworkManager");
    networking.wireless.iwd.enable = true;
    networking.wireless.dbusControlled = true;
    networking.wireless.athUserRegulatoryDomain = true;

    # Must always be false
    networking.useDHCP = false;

    networking.hostId = mkDefault (builtins.abort "Default hostId not changed" null);
    networking.hostName = mkDefault (builtins.abort "Default hostname not changed" null);

    # Needed for proper WiFi support in some countries (like France, for instance)
    hardware.wirelessRegulatoryDatabase = mkDefault true;

    networking.firewall.allowPing = !desktopCfg.enable;
  };
}
