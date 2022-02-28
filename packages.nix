{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.programs;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  optimizeWithFlag = pkg: flag:
    pkg.overrideAttrs (attrs: {
      NIX_CFLAGS_COMPILE = (attrs.NIX_CFLAGS_COMPILE or "") + " ${flag}";
      doCheck = false;
    });
  optimizeWithFlags = pkg: flags: pkgs.lib.foldl' (pkg: flag: optimizeWithFlag pkg flag) pkg flags;
  optimizeForThisHost = pkg: optimizeWithFlags pkg (builtins.trace "${toString config.aviallon.programs.compileFlags}" config.aviallon.programs.compileFlags);
in
{
  imports = [
    ./programs/nano.nix
    ./programs/git.nix
    ./programs/htop.nix
  ];

  options.aviallon.programs = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's programs";
      type = types.bool;
    };
    compileFlags = mkOption {
      default = [ "-O3" "-march=${generalCfg.cpuArch}" "-mtune=${generalCfg.cpuTune}" ];
      example = [ "-O2" "-mavx" ];
      description = "Add specific compile flags";
      type = types.listOf types.str;
    };
    allowUnfreeList = mkOption {
      default = [ ];
      example = [ "nvidia-x11" "steam" ];
      description = "Allow specific unfree software to be installed";
      type = types.listOf types.str;
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.config.packageOverrides = pkgs:
      let
          optimizePackage = optimizeForThisHost pkgs;
      in {
          nano = optimizeForThisHost pkgs.nano;
          rsyncOptimized = optimizeForThisHost pkgs.rsync;

          opensshOptimized = optimizeForThisHost pkgs.openssh;

          nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
              inherit pkgs;
          };
      };

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.allowUnfreeList;

    environment.systemPackages = with pkgs; with libsForQt5; [
      vim
      wget
      nano
      opensshOptimized
      rsyncOptimized
      htop
      cachix
    ];

    programs.ssh.package = pkgs.opensshOptimized;

    programs.ccache.enable = true;
    programs.ccache.packageNames = [
    #  config.boot.kernelPackages.kernel
  #    "opensshOptimized"
  #    "rsyncOptimized"
    ];
    nix.sandboxPaths = [
      (toString config.programs.ccache.cacheDir)
    ];

  };
}
