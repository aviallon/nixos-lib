{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  buildUserKeyFile = "remote_builder/id_builder";
  buildUserPubKey = readFile ./nix/id_builder.pub;
  buildUserKey = readFile ./nix/id_builder;

  getSpeed = cores: threads: cores + (threads - cores) / 2;
  mkBuildMachine = {
  hostName,
  cores,
  threads ? (cores * 2),
  features ? [ ],
  x86ver ? 1 }:
  rec {
    inherit hostName;
    system = "x86_64-linux";
    maxJobs = cores / 2;
    sshUser = "builder";
    sshKey = "/etc/${buildUserKeyFile}";
    speedFactor = getSpeed cores threads; 
    supportedFeatures = [ "kvm" "benchmark" ]
      ++ optional (speedFactor > 8) "big-parallel"
      ++ optional (x86ver >= 2) "gccarch-x86-64-v2"
      ++ optional (x86ver >= 3) "gccarch-x86-64-v3"
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
    cores = mkOption {
      default = null;
      example = 4;
      description = "Number of physical threads of the machine";
      type = with types; nullOr ints.positive;
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
      "i915.mitigations" = "off";
      "i915.enable_dc" = 4;
      "i915.fastboot" = 1;
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

    environment.etc."${buildUserKeyFile}".text = buildUserKey;
    nix.buildMachines = [
      {
        hostName = "lesviallon.fr";
        system = "x86_64-linux";
        maxJobs = 2;
        speedFactor = 4;
        supportedFeatures = [ "kvm" "benchmark" "big-parallel" ];
      }
    ];
    users.users.builder = {
      isSystemUser = true;
      group = "builder";
      hashedPassword = mkForce null; # Must not have a password!
      openssh.authorizedKeys.keys = [
        buildUserPubKey
      ];
    };
    users.groups.builder = {};
    nix.trustedUsers = [ "builder" ];
    nix.distributedBuilds = mkDefault false;
  };

}
