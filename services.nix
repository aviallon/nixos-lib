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
      type = types.attrs;
      description = "Add extra config to journald with Nix language";
    };
  };

  config = mkIf cfg.enable {
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
  #  services.openssh.permitRootLogin = "prohibit-password";
    services.openssh.permitRootLogin = mkDefault "yes";
    networking.firewall.allowedTCPPorts = [ 22 ];
    networking.firewall.allowedUDPPorts = [ 22 ];

    services.rsyncd.enable = !desktopCfg.enable;

    services.fstrim.enable = true;

    services.haveged.enable = (builtins.compareVersions config.boot.kernelPackages.kernel.version "5.6" < 0);

    services.irqbalance.enable = true;

    services.printing = mkIf desktopCfg.enable {
      enable = true;
      defaultShared = mkDefault true;
      browsing = mkDefault true;
      drivers = with pkgs; [
        hplipWithPlugin
        gutenprint
        splix
        brlaser
        cups-bjnp
        # cups-dymo
        # cups-zj-58
        # cups-kyocera
        cups-filters
        carps-cups
        # cups-kyodialog3
        cups-brother-hl1110
        cups-toshiba-estudio
        cups-brother-hl1210w
        hll2390dw-cups
        cups-brother-hl3140cw
        cups-brother-hll2340dw
        cups-drv-rastertosag-gdi
        # cups-kyocera-ecosys-m552x-p502x
        canon-cups-ufr2
      ];
      webInterface = mkDefault true;
    };

    hardware.sane = mkIf desktopCfg.enable {
      enable = true;
      netConf = "192.168.0.0/24";
      extraBackends = with pkgs; [
        hplipWithPlugin
      ];
    };
    
    aviallon.programs.allowUnfreeList = [
      "hplip"
      "hplipWithPlugin"
      "cups-bjnp"
      "cups-dymo"
      "cups-zj-58"
      "cups-kyocera"
      "cups-filters"
      "carps-cups"
      "cups-kyodialog3"
      "cups-brother-hl1110"
      "cups-toshiba-estudio"
      "cups-brother-hl1210w"
      "cups-brother-hl1210W"
      "hll2390dw-cups"
      "cups-brother-hl3140cw"
      "cups-brother-hll2340dw"
      "cups-drv-rastertosag-gdi"
      "cups-kyocera-ecosys-m552x-p502x"
      "canon-cups-ufr2"
    ];

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
      (ifEnable false { name = "hdapsd";
        type = "LowLatency_RT";
        sched = "fifo";
        rtprio = 99;
        ioclass = "realtime";
        ionice = 0;
        oom_score_adj = -999;
        nice = -20;
      })
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

    programs.gnupg = {
      agent.enable = true;
      dirmngr.enable = true;
      agent.pinentryFlavor = "curses";
      agent.enableSSHSupport = true;
      agent.enableExtraSocket = true;
      agent.enableBrowserSocket = true;
    };
    programs.ssh.startAgent = false;

    # SmartCards
    services.pcscd.enable = true;

    services.avahi = {
      enable = true; # .lan/.local resolution
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
