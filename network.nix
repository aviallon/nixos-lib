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
    useNetworkManager = mkOption {
      default = desktopCfg.enable;
      example = !desktopCfg.enable;
      description = "Enable NetworkManager";
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    networking.useNetworkd = mkOverride 500 true;
    networking.networkmanager.enable = cfg.useNetworkManager;
    networking.networkmanager.wifi.backend = "iwd";

    networking.dhcpcd.enable = !config.networking.useNetworkd;

    # Must always be false
    networking.useDHCP = false;

    networking.hostId = lib.mkDefault (builtins.abort "Default hostId not changed" null);
    networking.hostName = lib.mkDefault (builtins.abort "Default hostname not changed" null);

    networking.firewall.allowPing = !desktopCfg.enable;
  };
}
