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
    system.autoUpgrade.operation = "boot";
    system.autoUpgrade.persistent = true;
    system.autoUpgrade.rebootWindow = {
      lower = "01:00";
      upper = "05:00";
    };

    system.build.nixos-rebuild = let
      nixos-rebuild = pkgs.nixos-rebuild.override { nix = config.nix.package.out; };
      nixos-rebuild-inhibit = pkgs.writeShellScriptBin "nixos-rebuild" ''
        exec ${config.systemd.package}/bin/systemd-inhibit --what=idle:shutdown --mode=block \
          --who="NixOS rebuild" \
          --why="NixOS must finish rebuilding configuration or work would be lost." \
          -- \
            ${pkgs.coreutils}/bin/nice -n 19 -- ${nixos-rebuild}/bin/nixos-rebuild "$@"
        '';
    in mkOverride 20 nixos-rebuild-inhibit;

    environment.systemPackages = [
      (hiPrio config.system.build.nixos-rebuild)
    ];
    
    systemd.services.nixos-upgrade = {
      unitConfig = {
        ConditionCPUPressure = "user.slice:15%";
        ConditionMemoryPressure = "user.slice:50%";
        ConditionIOPressure = "user.slice:50%";
      };
      serviceConfig = {
        Nice = 19;
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        IOAccounting = true;
        IOWeight = 1024 / 10;
        CPUWeight = 1;
        CPUQuota = (toString (generalCfg.cores * 80)) + "%";
        Type = mkOverride 20 "simple";
      };
    };



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
      ++ optional ( ! isNull generalCfg.cpu.arch ) "gccarch-${generalCfg.cpu.arch}"
      ++ optional ( generalCfg.cpu.x86.level >= 2 ) "gccarch-x86-64-v2"
      ++ optional ( generalCfg.cpu.x86.level >= 3 ) "gccarch-x86-64-v3"
      ++ optional ( generalCfg.cpu.x86.level >= 4 ) "gccarch-x86-64-v4"
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
