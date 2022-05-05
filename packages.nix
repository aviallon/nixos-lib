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

        # Pipe outputs instead of using intermediate files
        "-pipe"
        
        "--param=ssp-buffer-size=32"
        
        "-fasynchronous-unwind-tables"

        # Use re-entrant libc functions whenever possible
        "-Wp,-D_REENTRANT"

        # Fat LTO objects are object files that contain both the intermediate language and the object code. This makes them usable for both LTO linking and normal linking.
        # "-flto=auto" # Use -flto=auto to use GNU make’s job server, if available, or otherwise fall back to autodetection of the number of CPU threads present in your system.
        # "-ffat-lto-objects"

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

        "-Wl,--enable-new-dtags"
        "-Wa,-mbranches-within-32B-boundaries"

        # Stream extra information needed for aggressive devirtualization when running the link-time optimizer in local transformation mode.
        # "-fdevirtualize-at-ltrans"

        ##### Very aggressive and experimental options ######
        "-fmodulo-sched"
        "-fmodulo-sched-allow-regmoves"
        "-fgcse-sm" # "This pass attempts to move stores out of loops."
        "-fgcse-las" # "global common subexpression elimination pass eliminates redundant loads that come after stores to the same memory location"
        "-fdevirtualize-speculatively" # "Attempt to convert calls to virtual functions to speculative direct calls"

        # Reduce code size, improving cache locality
        "-fira-hoist-pressure" # "Use IRA to evaluate register pressure in the code hoisting pass for decisions to hoist expressions. This option usually results in smaller code, but it can slow the compiler down."
        "-fira-loop-pressure" # "Use IRA to evaluate register pressure in loops for decisions to move loop invariants. This option usually results in generation of faster and smaller code on machines with large register files."
        "-flive-range-shrinkage" # "Attempt to decrease register pressure through register live range shrinkage. This is helpful for fast processors with small or moderate size register sets."
        "-fschedule-insns" # "If supported for the target machine, attempt to reorder instructions to eliminate execution stalls due to required data being unavailable."
        "-fsched-pressure" # "Enable register pressure sensitive insn scheduling before register allocation."
        "-fsched-spec-load" # "Allow speculative motion of some load instructions."
        "-fsched-stalled-insns=4" # Define how many insns (if any) can be moved prematurely from the queue of stalled insns into the ready list during the second scheduling pass"
        "-ftree-loop-ivcanon" # "Create a canonical counter for number of iterations in loops for which determining number of iterations requires complicated analysis."
        "-ftree-loop-im" # "Perform loop invariant motion on trees."
        "-ftree-vectorize" # "Perform vectorization on trees."

        # Super experimental
        "-fgraphite-identity" # "Enable the identity transformation for graphite."
        "-floop-nest-optimize" # "Enable the isl based loop nest optimizer."
        "-floop-parallelize-all" # "Use the Graphite data dependence analysis to identify loops that can be parallelized."

        ## To be tested
        ## "-ftree-parallelize-loops=N" : Parallelize loops, i.e., split their iteration space to run in n threads. This is only possible for loops whose iterations are independent and can be arbitrarily reordered.
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
