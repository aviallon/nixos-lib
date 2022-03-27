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
      default = [
        "-O3" "-march=${generalCfg.cpuArch}" "-mtune=${generalCfg.cpuTune}"
        "-feliminate-unused-debug-types" "--param=ssp-buffer-size=32"
        # "-Wl,--copy-dt-needed-entries-m64-fasynchronous-unwind-tables"
        "-fasynchronous-unwind-tables"
        "-fno-semantic-interposition"
        "-ffat-lto-objects"
        "-fno-signed-zeros"
        "-fno-trapping-math"
        "-fassociative-math"
        "-fexceptions"
        "-ftree-loop-distribute-patterns"
        "-Wl,-sort-common"
        "-fno-semantic-interposition"
        "-fipa-pta"
        "-fdevirtualize-at-ltrans"
        ];
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
      ripgrep
      fd
      parallel
      pciutils
      coreutils-full

      gcc
      gnumake
      cmake
    ];

    programs.ssh.package = pkgs.opensshOptimized;

    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 9999;
      newSession = true;
    };

    aviallon.programs.allowUnfreeList = [
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
