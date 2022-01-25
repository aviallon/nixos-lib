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

  nixConfig = settings: (generators.toKeyValue {
    mkKeyValue = generators.mkKeyValueDefault {
      mkValueString = nixConfigValue;
    } " = ";
  } (filterAttrs (n: v: !(
      (v == null) ||
      (isList v && (length v == 0))
    ))
    settings)
  );
in
{
  options.aviallon.general = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's general tuning";
      type = types.bool;
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

    boot.kernelParams = concatLists [
      (optional cfg.unsafeOptimizations "mitigations=off")
    ];

    powerManagement.cpuFreqGovernor = mkDefault "schedutil";

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs.mtr.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    nix.gc.automatic = mkDefault true;
    nix.gc.randomizedDelaySec = "30min";
    nix.optimise.automatic = mkDefault true;
    nix.autoOptimiseStore = mkDefault true;

    nix.daemonIOSchedPriority = 5;
    nix.daemonCPUSchedPolicy = "batch";
    nix.daemonIOSchedClass = "idle";

    system.autoUpgrade.enable = mkDefault true;
    system.autoUpgrade.allowReboot = mkIf (!desktopCfg.enable) (mkDefault true);
    system.autoUpgrade.dates = "00:00";


    nixpkgs.localSystem.system = builtins.currentSystem;
    nixpkgs.localSystem.platform  = lib.systems.platforms.pc // {
      gcc.arch = cfg.cpuArch;
      gcc.tune = cfg.cpuTune;
    };

    nix.buildMachines = [
      {
        hostName = "lesviallon.fr";
        system = "x86_64-linux";
        maxJobs = 2;
        speedFactor = 4;
        supportedFeatures = [ "kvm" "benchmark" "big-parallel" ];
      }
    ];
    nix.distributedBuilds = mkDefault false;

    nix.package = mkIf cfg.flakes.enable (if (builtins.compareVersions pkgs.nix.version "2.4" >= 0) then pkgs.nix else pkgs.nix_2_4);
    nix.extraOptions = nixConfig {
      builders-use-substitutes = true;
      experimental-features = concatLists [
        (optionals cfg.flakes.enable ["nix-command" "flakes"])
      ];
      download-attempts = 5;
      stalled-download-timeout = 20;
    };

  };

}
