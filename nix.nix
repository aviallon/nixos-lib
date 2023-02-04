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
    system.autoUpgrade.dates = "Sunday *-*-* 02:00";


    nix.gc.automatic = mkDefault true;
    nix.gc.dates = mkDefault "Monday,Wednesday,Friday,Sunday 03:00:00";
    nix.gc.randomizedDelaySec = "3h";
    nix.optimise.automatic = mkDefault (!config.nix.settings.auto-optimise-store);
    nix.optimise.dates = mkDefault [ "Tuesday,Thursday,Saturday 03:00:00" ];
    nix.settings.auto-optimise-store  = mkDefault true;

    systemd.services.nix-daemon = {
      serviceConfig = {
        Nice = 19;
        CPUSchedulingPolicy = mkForce "batch";
        IOSchedulingClass = mkForce "idle";
        IOAccounting = true;
        IOWeight = 1024 / 10;
      };
    };

  
    nix.package = mkIf (strings.versionOlder pkgs.nix.version "2.7") pkgs.nix_2_7;

    nix.settings.system-features = [ "big-parallel" "kvm" "benchmark" ]
      ++ optional ( ! isNull generalCfg.cpuArch ) "gccarch-${generalCfg.cpuArch}"
    ;

    nix.settings.builders-use-substitutes = true;
    nix.settings.experimental-features = []
      ++ optionals ( strings.versionOlder "2.4" pkgs.nix.version ) [ "nix-command" "flakes" ];

    nix.settings.download-attempts = 5;
    nix.settings.stalled-download-timeout = 20;

    nix.settings.substituters = mkIf cfg.enableCustomSubstituter (mkBefore [ "https://nix-cache.lesviallon.fr" ]);
    nix.settings.trusted-public-keys = mkIf cfg.enableCustomSubstituter (mkBefore [ "nix-cache.lesviallon.fr-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ]);

    nix.settings.cores = mkIf (generalCfg.cores != null) generalCfg.cores;
    nix.settings.max-jobs = mkIf (generalCfg.cores != null) (math.log2 generalCfg.cores);

  };
}
