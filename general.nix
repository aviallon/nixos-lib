{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  buildUserPubKeyFile = ./nix/id_builder.pub;
  buildUserKeyFile = ./nix/id_builder;

  getSpeed = cores: threads: cores + (threads - cores) / 2;

  mkBuildMachine = {
    hostName,
    cores,
    systems ? [ "x86_64-linux" ] ,
    threads ? (cores * 2),
    features ? [ ],
    x86ver ? 1 ,
    ...
  }@attrs: let
    speedFactor = getSpeed cores threads;
  in {
    inherit hostName speedFactor;
    systems = systems
      ++ optional (any (s: s == "x86_64-linux") systems) "i686-linux"
    ;
    sshUser = "builder";
    sshKey = toString buildUserKeyFile;
    maxJobs = myLib.math.log2 cores;
    supportedFeatures = [ "kvm" "benchmark" ]
      ++ optional (speedFactor > 8) "big-parallel"
      ++ optional (x86ver >= 2) "gccarch-x86-64-v2"
      ++ optional (x86ver >= 3) "gccarch-x86-64-v3"
      ++ optional (x86ver >= 4) "gccarch-x86-64-v4"
      ++ features
    ;
    
  };
in
{
  imports = [
    (mkRemovedOptionModule [ "aviallon" "general" "flakes" "enable" ] "Flakes are now enabled by default")
  ];

  options.aviallon.general = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's general tuning";
      type = types.bool;
    };

    minimal = mkEnableOption "minimal installation";
    
    cores = mkOption {
      default = null;
      example = 4;
      description = "Number of physical threads of the machine";
      type = with types; nullOr ints.positive;
    };

    cpuVendor = mkOption {
      default = null;
      example = "amd";
      description = "Vendor of you CPU. Either AMD or Intel";
      type = types.str;
    };
    
    cpuArch = mkOption {
      default = "x86-64";
      example = "x86-64-v2";
      description = "Set CPU arch used in overlays, ...";
      type = types.str;
    };
    cpuTune = mkOption {
      default = "generic";
      example = "sandybridge";
      description = "Set CPU tuning for compilers";
      type = types.str;
    };
    unsafeOptimizations = mkEnableOption "unsafe system tuning";
    debug = mkEnableOption "debug-specific configuration";
  };

  config = mkIf cfg.enable {
    # Set your time zone.
    time.timeZone = "Europe/Paris";

    # Select internationalisation properties.
    i18n = {
      defaultLocale = "fr_FR.UTF-8";
    };

    console = {
      keyMap = "fr-pc";
      font = "Lat2-Terminus16";
    };

    aviallon.boot.cmdline = mkIf cfg.unsafeOptimizations {
      mitigations = "off";
    };

    powerManagement.cpuFreqGovernor = mkDefault "schedutil";

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs.mtr.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    documentation.nixos.includeAllModules = true;
    documentation.nixos.enable = true;
    documentation.dev.enable = true;
    documentation.man.generateCaches = true;


    environment.shellInit = concatStringsSep "\n" [
      ''export GPG_TTY="$(tty)"''
      ''gpg-connect-agent /bye''
      ''export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"''
    ];


    nixpkgs.localSystem.system = builtins.currentSystem;
    nixpkgs.localSystem.platform  = lib.systems.platforms.pc // {
      gcc.arch = cfg.cpuArch;
      gcc.tune = cfg.cpuTune;
    };

    # zram is so usefull, we should always have it enabled.
    zramSwap = {
      enable = true;
      priority = 10000;
      memoryPercent = 100;
      algorithm = "zstd";
    };

    environment.noXlibs = mkIf (cfg.minimal && (!desktopCfg.enable)) true;

    nix.buildMachines = []
      ++ optional false (mkBuildMachine {
        hostName = "luke-skywalker-nixos.local";
        cores = 8;
        threads = 16;
      })
      ++ optional false (mkBuildMachine {
        hostName = "cachan.lesviallon.fr";
        cores = 6;
        threads = 6;
      })
    ;

    programs.ssh.extraConfig = ''
      Host cachan.lesviallon.fr
        Port 52222
    '';
    
    users.users.builder = {
      isSystemUser = true;
      group = "builder";
      hashedPassword = mkForce null; # Must not have a password!
      openssh.authorizedKeys.keys = [
        (readFile buildUserPubKeyFile)
      ];
      shell = pkgs.bashInteractive;
    };
    users.groups.builder = {};
    nix.settings.trusted-users = [ "builder" ];
    nix.distributedBuilds = mkDefault true;
  };

}
