{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.programs;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

in
{
  imports = [
    ./programs/nano.nix
    ./programs/git.nix
    ./programs/htop.nix
    ./overlays.nix
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

    programs.java.enable = true;

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.allowUnfreeList;

    environment.systemPackages = with pkgs; with libsForQt5; [
      vim
      wget
      nano
      opensshOptimized
      rsyncOptimized
      htop
      cachix
      psmisc # killall, etc.
      par2cmdline # .par2 archive verification
      schedtool
      python3
      veracrypt
    ];

    programs.ssh.package = pkgs.opensshOptimized;

    programs.steam.enable = true;
    hardware.steam-hardware.enable = true;
    programs.steam.remotePlay.openFirewall = true;
    aviallon.programs.allowUnfreeList = [
      "steam" "steam-original" "steam-runtime"
      "veracrypt"
    ];

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
