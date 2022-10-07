{config, pkgs, lib, myLib, ...}:
with lib;
with myLib;
let
  cfg = config.aviallon.nix;
  generalCfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.nix = {
    enableCustomSubstituter = mkEnableOption "custom substituter using nix-cache.lesviallon.fr";
  };
  
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
      experimental-features = [ "nix-command" "flakes"];
      download-attempts = 5;
      stalled-download-timeout = 20;
    };

    nix.binaryCaches = mkIf cfg.enableCustomSubstituter (mkBefore [ "https://nix-cache.lesviallon.fr" ]);
    nix.binaryCachePublicKeys = mkIf cfg.enableCustomSubstituter (mkBefore [ "nix-cache.lesviallon.fr-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ]);

    nix.buildCores = mkIf (generalCfg.cores != null) generalCfg.cores;
    nix.maxJobs = mkIf (generalCfg.cores != null) (math.log2 generalCfg.cores);

  };
}
