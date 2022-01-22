{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.services;
  desktopCfg = config.aviallon.desktop;
in {
  options.aviallon.services = {
    enable = mkOption {
      default = true;
      example = false;
      type = types.bool;
      description = "Enable aviallon's services configuration";
    };
  };

  config = mkIf cfg.enable {
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
  #  services.openssh.permitRootLogin = "prohibit-password";
    services.openssh.permitRootLogin = "yes";
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.allowedUDPPorts = [ 22 ];

    services.rsyncd.enable = !desktopCfg.enable;

    services.fstrim.enable = true;

    services.haveged.enable = (builtins.compareVersions config.boot.kernelPackages.kernel.version "5.6" < 0);

    services.irqbalance.enable = true;

    services.printing.enable = desktopCfg.enable;

    services.fwupd.enable = true;

    services.ananicy.enable = true;
    services.ananicy.package = pkgs.ananicy-cpp;
    services.ananicy.settings = {
      loglevel = "info";
      cgroup_realtime_workaround = false;
    };
    services.ananicy.extraRules = concatStringsSep "\n" ( forEach [
      {
        name = "cp";
        type = "BG_CPUIO";
      }
    ] (x: builtins.toJSON x));

    services.avahi.enable = true; # .lan/.local resolution
    services.avahi.nssmdns = true; # .lan/.local resolution
    services.avahi.publish.enable = true;
    services.avahi.publish.hinfo = true; # Whether to register a mDNS HINFO record which contains information about the local operating system and CPU.
  };
}
