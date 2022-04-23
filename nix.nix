{config, pkgs, lib, myLib, ...}:
with lib;
with myLib;
let
  generalCfg = config.aviallon.general;
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
in
{
  config = {

    system.autoUpgrade.enable = mkDefault true;
    system.autoUpgrade.allowReboot = mkIf (!desktopCfg.enable) (mkDefault true);
    system.autoUpgrade.dates = "Sunday *-*-* 00:00";


    nix.gc.automatic = mkDefault true;
    nix.gc.dates = mkDefault "Monday,Wednesday,Friday,Sunday 03:00:00";
    nix.gc.randomizedDelaySec = "3h";
    nix.optimise.automatic = mkDefault true;
    nix.optimise.dates = mkForce [ "Tuesday,Thursday,Saturday 03:00:00" ];
    nix.autoOptimiseStore = mkDefault true;

    nix.daemonIOSchedPriority = 5;
    nix.daemonCPUSchedPolicy = "batch";
    nix.daemonIOSchedClass = "idle";

  
    nix.package = mkIf generalCfg.flakes.enable (
      if (builtins.compareVersions pkgs.nix.version "2.4" >= 0)
      then pkgs.nix
      else pkgs.nix_2_4
    );
    nix.extraOptions = nixConfig {
      builders-use-substitutes = true;
      experimental-features = concatLists [
        (optionals generalCfg.flakes.enable ["nix-command" "flakes"])
      ];
      download-attempts = 5;
      stalled-download-timeout = 20;
    };

    nix.buildCores = mkIf (generalCfg.cores != null) generalCfg.cores;
    nix.maxJobs = mkIf (generalCfg.cores != null) (math.log2 generalCfg.cores);

  };
}
