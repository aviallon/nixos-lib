{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  nixConfigValue = value:
    if value == true then "true"
    else if value == false then "false"
    else if isList value then toString value
    else generators.mkValueStringDefault { } value;

  isNullOrEmpty = v: (v == null) ||
      (isList v && (length v == 0));

  nixConfig = settings: (generators.toKeyValue {
    mkKeyValue = generators.mkKeyValueDefault {
      mkValueString = nixConfigValue;
    } " = ";
  } (filterAttrs (n: v: !(isNullOrEmpty v))
    settings)
  );

  log2 = let
    mylog = x: y: if (x >= 2) then mylog (x / 2) (y + 1) else y;
  in x: mylog x 0;
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
      ++ optional (x86ver >= 2) "arch-x86-64-v2"
      ++ optional (x86ver >= 3) "arch-x86-64-v3"
    ;
  };
in
{
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
      type = types.nullOr (types.addCheck types.int (x: x > 0));
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
    flakes.enable = mkEnableOption "experimental flake support";
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

    nix.gc.automatic = mkDefault true;
    nix.gc.dates = mkDefault "Monday,Wednesday,Friday,Sunday 03:00:00";
    nix.gc.randomizedDelaySec = "3h";
    nix.optimise.automatic = mkDefault true;
    nix.optimise.dates = mkForce [ "Tuesday,Thursday,Saturday 03:00:00" ];
    nix.autoOptimiseStore = mkDefault true;

    nix.daemonIOSchedPriority = 5;
    nix.daemonCPUSchedPolicy = "batch";
    nix.daemonIOSchedClass = "idle";

    system.autoUpgrade.enable = mkDefault true;
    system.autoUpgrade.allowReboot = mkIf (!desktopCfg.enable) (mkDefault true);
    system.autoUpgrade.dates = "Sunday *-*-* 00:00";

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

    nix.package = mkIf cfg.flakes.enable (if (builtins.compareVersions pkgs.nix.version "2.4" >= 0) then pkgs.nix else pkgs.nix_2_4);
    nix.extraOptions = nixConfig {
      builders-use-substitutes = true;
      experimental-features = concatLists [
        (optionals cfg.flakes.enable ["nix-command" "flakes"])
      ];
      download-attempts = 5;
      cores = ifEnable (cfg.cores != null) cfg.cores;
      stalled-download-timeout = 20;
      connect-timeout = 5;
    };

    nix.maxJobs = mkIf (cfg.cores != null) (log2 cfg.cores);
  };

}
