{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.services;
  desktopCfg = config.aviallon.desktop;
  laptopCfg = config.aviallon.laptop;
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

  imports = [
    ./services
  ];

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
      type = with types; attrsOf (oneOf [ bool int str ]);
      description = "Add extra config to journald with Nix language";
    };
  };

  config = mkIf cfg.enable {
    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = {
        X11Forwarding = mkDefault config.services.xserver.enable;
        PermitRootLogin = mkDefault "prohibit-password";
      };
      openFirewall = true;
      startWhenNeeded = true;
    };

    # Better reliability and performance
    services.dbus.implementation = "broker";

    systemd.services."ssh-inhibit-sleep@" = {
      description = "Inhibit sleep when SSH connections are active";
      bindsTo = [ "sshd@%i.service" ];
      script = ''
        exec ${pkgs.systemd}/bin/systemd-inhibit --mode block --what sleep \
          --who "ssh session $1" \
          --why "remote session still active" \
          ${pkgs.coreutils}/bin/sleep infinity
      '';
      scriptArgs = "%I";
      wantedBy = [ "sshd@.service" ];
    };
    
    programs.ssh.setXAuthLocation = config.services.xserver.enable;
    programs.ssh.forwardX11 = mkDefault config.services.xserver.enable;
    security.pam.services.sudo.forwardXAuth = mkDefault true; # Easier to start GUI programs as root
    

    
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.allowedUDPPorts = [ 22 5353 ];

    services.rsyncd.enable = !desktopCfg.enable;

    services.fstrim.enable = true;

    services.haveged.enable = (builtins.compareVersions config.boot.kernelPackages.kernel.version "5.6" < 0);

    services.irqbalance.enable = true;

    services.fwupd.enable = true;

    services.journald.extraConfig = mkOverride 2 (journaldConfig cfg.journald.extraConfig);

    aviallon.services.journald.extraConfig = {
      Storage = mkIf generalCfg.unsafeOptimizations "volatile";
    };

    services.ananicy.enable = false;
    services.ananicy.package = pkgs.ananicy-cpp;
    services.ananicy.settings = {
      loglevel = "info";
      cgroup_realtime_workaround = false;
    };
    services.ananicy.extraRules = concatStringsSep "\n" ( forEach [
      { name = "cp";
        type = "BG_CPUIO"; }
      { name = "nix-build";
        type = "BG_CPUIO"; }
      { name = "nix-store";
        type = "BG_CPUIO"; }
      { name = "nix-collect-garbage";
        type = "BG_CPUIO"; }
      { name = "nix";
        type = "BG_CPUIO"; }
      { name = "X";
        type = "LowLatency_RT"; }
      { name = "htop";
        type = "LowLatency_RT"; }
    ] (x: builtins.toJSON x));


    # Enusre low-latency response for this time-critical service
    systemd.services."hdapsd@" = {
      serviceConfig = {
        Nice = -20;
        CPUSchedulingPolicy = "fifo";
        CPUSchedulingPriority = 99;
        IOSchedulingClass = "realtime";
        IOSchedulingPriority = 0;
      };
    };

    programs.ssh.startAgent = false;

    # SmartCards
    services.pcscd.enable = mkDefault (!generalCfg.minimal);

    services.avahi = {
      enable = !generalCfg.minimal; # .lan/.local resolution
      nssmdns = true; # .lan/.local resolution
      openFirewall = true;
      reflector = true;
      publish = {
        enable = true;
        domain = true;
        userServices = true;
        addresses = true;
        workstation = mkDefault (desktopCfg.enable && !laptopCfg.enable);
        hinfo = true; # Whether to register a mDNS HINFO record which contains information about the local operating system and CPU.
      };
    };


    services.nginx = {
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
    };
  };
}
