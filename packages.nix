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
        "-feliminate-unused-debug-types"
        "--param=ssp-buffer-size=32"
        
        "-fno-asynchronous-unwind-tables"

        # Fat LTO objects are object files that contain both the intermediate language and the object code. This makes them usable for both LTO linking and normal linking.
        # "-flto=auto" # Use -flto=auto to use GNU make’s job server, if available, or otherwise fall back to autodetection of the number of CPU threads present in your system.
        "-ffat-lto-objects"

        # Math optimizations leading to loss of precision
        "-fno-signed-zeros"
        "-fno-trapping-math"
        "-fassociative-math"

        # Perform loop distribution of patterns that can be code generated with calls to a library (activated at O3 and more)
        "-ftree-loop-distribute-patterns"
        
        "-Wl,-sort-common"

        # The compiler assumes that if interposition happens for functions the overwriting function will have precisely the same semantics (and side effects)
        "-fno-semantic-interposition"
        
        # Perform interprocedural pointer analysis and interprocedural modification and reference analysis. This option can cause excessive memory and compile-time usage on large compilation units.
        "-fipa-pta"


        "-fdevirtualize-speculatively"
        
        # Stream extra information needed for aggressive devirtualization when running the link-time optimizer in local transformation mode.
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
    programs.ccache.packageNames = [  ];
    
    nix.sandboxPaths = [
      (toString config.programs.ccache.cacheDir)
    ];

  };
}
