{config, pkgs, lib, myLib, nixpkgs, nixpkgs-unstable, ...}:
with lib;
with myLib;
let
  cfg = config.aviallon.nix;
  generalCfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  optimizeCfg = config.aviallon.optimizations;
  optimizePkg = optimizeCfg.optimizePkg;
in
{
  options.aviallon.nix = {
    enableCustomSubstituter = mkEnableOption "custom substituter using nix-cache.lesviallon.fr";
    contentAddressed = mkEnableOption "experimental content-addressed derivations";
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

    environment.variables = {
      NIX_REMOTE = "daemon"; # Use the nix daemon by default
    };
    
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
        IOWeight = 10;
        CPUWeight = 10;
        CPUQuota = (toString (generalCfg.cpu.threads * 80)) + "%";
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
        CPUWeight = 1;
        CPUQuota = (toString (generalCfg.cpu.threads * 80)) + "%";
        IOSchedulingClass = mkForce "idle";
        IOAccounting = true;
        IOWeight = 1;
      };
    };

  
    nix.package = optimizePkg { level = "slower"; } pkgs.nixVersions.latest;

    nix.settings.system-features = [ "big-parallel" "kvm" "benchmark" ]
      ++ optional ( ! isNull generalCfg.cpu.arch ) "gccarch-${generalCfg.cpu.arch}"
      ++ optional ( generalCfg.cpu.x86.level >= 2 ) "gccarch-x86-64-v2"
      ++ optional ( generalCfg.cpu.x86.level >= 3 ) "gccarch-x86-64-v3"
      ++ optional ( generalCfg.cpu.x86.level >= 4 ) "gccarch-x86-64-v4"
    ;

    nix.settings.builders-use-substitutes = true;
    nix.settings.substitute = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ]
      ++ optional (versionOlder config.nix.package.version "2.19") "repl-flake"
      ++ optional cfg.contentAddressed "ca-derivations"
    ;
    
    nix.settings.download-attempts = 5;
    nix.settings.stalled-download-timeout = 20;

    nix.settings.substituters = mkBefore ([]
      ++ optional cfg.enableCustomSubstituter "https://nix-cache.lesviallon.fr"
      ++ optional cfg.contentAddressed "https://cache.ngi0.nixos.org/"
    );
    nix.settings.trusted-public-keys = mkBefore ([]
      ++ optional cfg.enableCustomSubstituter "nix-cache.lesviallon.fr-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ++ optional cfg.contentAddressed "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA="
    );

    nix.settings.always-allow-substitutes = true;

    nix.settings.cores = mkIf (generalCfg.cpu.threads != null) generalCfg.cpu.threads;
    nix.settings.max-jobs = mkIf (generalCfg.cpu.threads != null) (math.log2 generalCfg.cpu.threads);

    nix.settings.hashed-mirrors = [ "https://tarballs.nixos.org" "https://nixpkgs-unfree.cachix.org" ];

    nix.registry = {
      nixpkgs.flake = nixpkgs;
      nixpkgs-unstable.flake = nixpkgs-unstable;
    };

    nix.nixPath = mkBefore [
      "nixpkgs=${nixpkgs.outPath}"
      "nixos-config=/etc/nixos/configuration.nix"
    ];

  };
}
