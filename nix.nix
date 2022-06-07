{config, pkgs, lib, myLib, ...}:
with lib;
with myLib;
let
  generalCfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
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

  
    nix.package = mkIf (strings.versionOlder pkgs.nix.version "2.7") pkgs.nix_2_7;
    
    nix.extraOptions = myLib.config.toNix {
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
