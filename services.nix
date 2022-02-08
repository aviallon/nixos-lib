{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.services;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  journaldConfigValue = value:
    if value == true then "true"
    else if value == false then "false"
    else if isList value then toString value
    else generators.mkValueStringDefault { } value;

  isNullOrEmpty = v: (v == null) ||
      (isList v && (length v == 0));

  journaldConfig = settings: (generators.toKeyValue {
    mkKeyValue = generators.mkKeyValueDefault {
      mkValueString = journaldConfigValue;
    } "=";
  } (filterAttrs (n: v: !(isNullOrEmpty v))
    settings)
  );
in {
  options.aviallon.services = {
    enable = mkOption {
      default = true;
      example = false;
      type = types.bool;
      description = "Enable aviallon's services configuration";
    };

    journald.extraConfig = mkOption {
      default = {};
      example = {};
      type = types.attrs;
      description = "Add extra config to journald with Nix language";
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

    services.journald.extraConfig = journaldConfig cfg.journald.extraConfig;

    aviallon.services.journald.extraConfig = ifEnable generalCfg.unsafeOptimizations {
      Storage = "volatile";
    };

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
      { name = "nix-build";
        type = "BG_CPUIO"; }
      { name = "nix-store";
        type = "BG_CPUIO"; }
      { name = "nix";
        type = "BG_CPUIO"; }
    ] (x: builtins.toJSON x));

    programs.gnupg = {
      agent.enable = true;
      dirmngr.enable = true;
      agent.enableSSHSupport = true;
      agent.enableExtraSocket = true;
      agent.enableBrowserSocket = true;
    };

    services.avahi.enable = true; # .lan/.local resolution
    services.avahi.nssmdns = true; # .lan/.local resolution
    services.avahi.publish.enable = true;
    services.avahi.publish.hinfo = true; # Whether to register a mDNS HINFO record which contains information about the local operating system and CPU.
  };
}
