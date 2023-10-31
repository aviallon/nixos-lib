{ config, pkgs, lib, myLib, options, ... }:
with lib;
let
  customKernelPatches = {
    enableX32ABI = {
      name = "enable-x32";
      patch = null;
      extraConfig = ''
        X86_X32 y
      '';
    };
    enableRTGroupSched = {
      name = "enable-rt-group-sched";
      patch = null;
      extraConfig = ''
        RT_GROUP_SCHED y
      '';
    };
    enableEnergyModel = {
      name = "enable-energy-model";
      patch = null; extraConfig = ''
        ENERGY_MODEL y
      '';
    };
    amdClusterId = {
      name = "cluster-id-amd";
      patch = pkgs.fetchpatch {
        url = "https://lkml.org/lkml/diff/2023/4/10/479/1";
        hash = "sha256-bpe+iWYQldlGiIlWr4XPbIBPQBetEjfRKZ0Te2I14dk=";
      };
      extraConfig = ''
        SCHED_CLUSTER y
      '';
    };
    backports = {
      zenLLCIdle = {
        name = "zen-llc-idle";
        patch = pkgs.fetchpatch {
          url = "https://git.kernel.org/pub/scm/linux/kernel/git/tip/tip.git/patch/?id=c5214e13ad60bd0022bab45cbac2c9db6bc1e0d4";
          hash = "sha256-3uDieD7XOaMM5yqOSvyLNsr2OqBxXESB5sM2gnGYoWk=";
        };
      };
    };
    
    optimizeForCPUArch = arch: let
      archConfigMap = {
        "k8" = "K8"; "opteron" = "K8"; "athlon64" = "K8"; "athlon-fx" = "K8";
        "k8-sse3" = "K8SSE3"; "opteron-sse3" = "K8SSE3"; "athlon64-sse3" = "K8SSE3";
        "znver1" = "ZEN"; "znver2" = "ZEN2"; "znver3" = "ZEN3"; "znver4" = "ZEN3";
        "bdver1" = "BULLDOZER"; "bdver2" = "PILEDRIVER"; "bdver3" = "STEAMROLLER"; "bdver4" = "EXCAVATOR";
        "barcelona" = "BARCELONA"; "amdfam10" = "BARCELONA";
        "btver1" = "BOBCAT"; "btver2" = "JAGUAR";

        "rocketlake" = "ROCKETLAKE"; "alderlake" = "ALDERLAKE";
        "sapphirerapids" = "SAPPHIRERAPIDS"; "tigerlake" = "TIGERLAKE"; "cooperlake" = "COOPERLAKE";
        "cascadelake" = "CASCADELAKE"; "icelake-server" = "ICELAKE"; "icelake-client" = "ICELAKE";
        "cannonlake" = "CANNONLAKE"; "skylake-avx512" = "SKYLAKEX";
        "tremont" = "GOLDMONTPLUS"; "goldmont-plus" = "GOLDMONTPLUS"; "goldmont" = "GOLDMONT";
        "silvermont" = "SILVERMONT"; "bonnel" = "GENERIC_CPU"; "skylake" = "SKYLAKE";
        "broadwell" = "BROADWELL"; "haswell" = "HASWELL";
        "ivybridge" = "IVYBRIDGE"; "sandybridge" = "SANDYBRIDGE";
        "westmere" = "WESTMERE"; "nehalem" = "NEHALEM";
        "core2" = "CORE2";
        "nocona" = "PSC"; "prescott" = "PSC"; "pentium4m" = "PSC"; "pentium4" = "PSC";

        "nano-3000" = "GENERIC_CPU2"; "nano-x2" = "GENERIC_CPU2"; "nano-x4" = "GENERIC_CPU2";
        
        "lujiazui" = "GENERIC_CPU2";
        
        "native" = "NATIVE_INTEL"; "x86-64-v2" = "GENERIC_CPU2"; "x86-64-v3" = "GENERIC_CPU3"; "x86-64-v4" = "GENERIC_CPU4";
      };
      
      archToConfig = arch:
        if (hasAttr arch archConfigMap) then archConfigMap."${arch}"
        else trace "Warning: '${arch}' not recognized, building for generic CPU" "GENERIC_CPU"
      ;
    in {
      name = "optimize-for-${arch}";
      patch = null;
      extraConfig = ''
        M${archToConfig arch} y
      '';
    };
  };

  toCmdlineValue = v: if (isBool v) then (if v then "y" else "n")
                        else if (isInt v || isString v) then (toString v)
                        else if (isList v) then (concatStringsSep "," v)
                        else throw "Invalid value for kernel cmdline parameter";

  toCmdlineList = set: mapAttrsToList
      (key: value:
        if (value == "") then
          "${key}"
        else
          "${key}=${toCmdlineValue value}"
      ) set;

  isXanmod = kernel: ! isNull (strings.match ".*(xanmod).*" kernel.modDirVersion);

  kernelVersionOlder = ver: versionOlder cfg.kernel.version ver;
  
  cfg = config.aviallon.boot;
  generalCfg = config.aviallon.general;
  allowUnfree = (types.isType types.attrs config.nixpkgs.config)
                && (hasAttr "allowUnfree" config.nixpkgs.config)
                && (getAttr "allowUnfree" config.nixpkgs.config);

  cpuConfig = config.aviallon.general.cpu;
in {

  options.aviallon.boot = {
    enable = mkOption {
      description = "Enable default boot settings";
      default = true;
      example = false;
      type = lib.types.bool;
    };
    useGrub = mkOption {
      description = "Use Grub instead of systemd-boot";
      default = !cfg.efi;
      example = cfg.efi;
      type = types.bool;
    };
    x32abi = {
      enable = mkEnableOption "X32 kernel ABI";
    };
    kvdo.enable = mkEnableOption "dm-kvdo kernel module";
    rtGroupSched.enable = mkEnableOption "RT cgroups";
    energyModel.enable = mkEnableOption "Energy Model";
    
    patches = {
      amdClusterId.enable = mkEnableOption "Energy Model";
      zenLLCIdle.enable = mkEnableOption "Zen LLC Idle patch";
    };
    
    efi = mkOption rec {
      description = "Use EFI bootloader";
      example = true;
      type = with types; bool;
    };
    legacy = mkOption rec {
      description = "Use legacy bootloader";
      default = !cfg.efi;
      example = true;
      type = with types; bool;
    };
    
    configurationLimit = mkOption {
      description = "Maximum number of generations in the boot menu";
      default = 3;
      example = null;
      type = types.int;
    };

    loops_per_jiffies = mkOption {
      description = "Set loops_per_jiffies to given constant, reducing boot-time. A value of 0 means autodetection.";
      default = 0;
      example = 4589490;
      type = types.addCheck types.int (v: v > 500 || v == 0);
    };

    cmdline = mkOption {
      description = "Kernel params as attributes (instead of list)";
      default = { };
      example = { "i915.fastboot" = true; };
      type = types.attrsOf (types.oneOf [ types.bool types.int types.str (types.listOf types.str) ]);
    };

    kernel = mkOption {
      description = "Linux kernel to use";
      default = options.boot.kernelPackages.default.kernel;
      example = "pkgs.kernel";
      type = types.package;
    };

    extraKCflags = mkOption {
      description = "If optimizations are enabled, add the specified values to kernel KCFLAGS";
      default = [];
      type = types.listOf types.string;
      example = [ "-fipa-pta" ];
    };
  };

  config = mkMerge [
  {
    assertions = [
      { assertion = cfg.efi -> !cfg.legacy;
        message = "exactly one of aviallon.boot.efi and aviallon.boot.legacy must be set";
      }
      { assertion = cfg.legacy -> cfg.useGrub;
        message = "Using GRUB is mandatory for legacy BIOS";
      }
    ];

    boot.kernelParams = toCmdlineList cfg.cmdline;
  } 
  (mkIf cfg.enable {
  
    hardware.enableAllFirmware = allowUnfree;
    hardware.enableRedistributableFirmware = true;

    aviallon.boot.cmdline = {
      "syscall.x32" = mkIf cfg.x32abi.enable true;

      # Reboot after 5 seconds on panic (prevent system lockup)
      "panic" = 5;

      # Sets loops_per_jiffy to given constant, thus avoiding time-consuming boot-time autodetection
      # https://www.kernel.org/doc/html/v5.15/admin-guide/kernel-parameters.html
      "lpj" = mkIf (cfg.loops_per_jiffies > 0) cfg.loops_per_jiffies;

    };

    nixpkgs.overlays = [(final: prev: {
      # Use bleeding-edge linux firmware
      linux-firmware = prev.unstable.linux-firmware;
    })];

    boot = {
      bootspec.enableValidation = true;
    
      initrd.kernelModules = [ ];
      initrd.availableKernelModules = [ "ehci_pci" ];

      kernelPackages = let
        baseKernel = cfg.kernel;
        # Possible CFLAGS source : (myLib.optimizations.makeOptimizationFlags {}).CFLAGS
        kCflags =
          [
            "-march=${cpuConfig.arch}"
            "-mtune=${cpuConfig.tune or cpuConfig.arch}"
          ]
          ++ optional (! isNull cpuConfig.caches.lastLevel ) "--param l2-cache-size=${toString cpuConfig.caches.lastLevel}"
          ++ optional (! isNull cpuConfig.caches.l1d ) "--param l1-cache-size=${toString cpuConfig.caches.l1d}"
          ++ cfg.extraKCflags;
        optimizedKernel =
          if config.aviallon.optimizations.enable then
            baseKernel.overrideAttrs (old: {
              KCFLAGS = (old.KCFLAGS or "") + (toString kCflags);
              passthru = baseKernel.passthru;
            })
          else
            baseKernel
          ;
      in mkOverride 2 (pkgs.linuxPackagesFor optimizedKernel);

      kernelPatches = []
        ++ optional cfg.x32abi.enable customKernelPatches.enableX32ABI
        ++ optional cfg.rtGroupSched.enable customKernelPatches.enableRTGroupSched
        ++ optional cfg.energyModel.enable customKernelPatches.enableEnergyModel
        ++ optional (cfg.patches.amdClusterId.enable && kernelVersionOlder "6.4") customKernelPatches.amdClusterId
        ++ optional (cfg.patches.zenLLCIdle.enable && kernelVersionOlder "6.5") customKernelPatches.backports.zenLLCIdle
        ++ optional (isXanmod cfg.kernel && config.aviallon.optimizations.enable) (customKernelPatches.optimizeForCPUArch config.aviallon.general.cpu.arch)
      ;


      loader.grub.enable = cfg.useGrub;
      loader.grub = {
        device = mkIf cfg.efi "nodev";
        efiSupport = cfg.efi;
        configurationLimit = cfg.configurationLimit;
      };

      loader.systemd-boot = {
        enable = cfg.efi && (!cfg.useGrub);
        configurationLimit = cfg.configurationLimit; 
      };

      loader.generic-extlinux-compatible = {
        configurationLimit = cfg.configurationLimit;
      };

      loader = {
        efi.efiSysMountPoint = mkDefault "/boot/efi";
        efi.canTouchEfiVariables = mkDefault true;
      };
    };
  })
  ];
}
