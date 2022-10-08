{ config, pkgs, lib, ... }:
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
    optimizeForCPUArch = arch: let
      archConfigMap = {
        "k8" = "K8"; "opteron" = "K8"; "athlon64" = "K8"; "athlon-fx" = "K8";
        "k8-sse3" = "K8SSE3"; "opteron-sse3" = "K8SSE3"; "athlon64-sse3" = "K8SSE3";
        "znver1" = "ZEN"; "znver2" = "ZEN2"; "znver3" = "ZEN3";
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
  
  cfg = config.aviallon.boot;
  generalCfg = config.aviallon.general;
  allowUnfree = (types.isType types.attrs config.nixpkgs.config)
                && (hasAttr "allowUnfree" config.nixpkgs.config)
                && (getAttr "allowUnfree" config.nixpkgs.config);
in
{

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
    efi = mkOption rec {
      description = "Use EFI bootloader";
      default = builtins.pathExists "/sys/firmware/efi";
      example = !default;
      type = types.bool;
    };
    configurationLimit = mkOption {
      description = "Maximum number of generations in the boot menu";
      default = 30;
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
  };

  config = {
    boot.kernelParams = toCmdlineList cfg.cmdline;
  } // (mkIf cfg.enable {
    boot.kernelParams = toCmdlineList cfg.cmdline;

    hardware.enableAllFirmware = allowUnfree;
    hardware.enableRedistributableFirmware = true;

    aviallon.boot.cmdline = {
      "syscall.x32" = cfg.x32abi.enable;

      # Reboot after 5 seconds on panic (prevent system lockup)
      "panic" = 5;

      # Sets loops_per_jiffy to given constant, thus avoiding time-consuming boot-time autodetection
      # https://www.kernel.org/doc/html/v5.15/admin-guide/kernel-parameters.html
      "lpj" = mkIf (cfg.loops_per_jiffies > 0) cfg.loops_per_jiffies;

    };

    aviallon.boot.useGrub = mkIf (!cfg.efi) (mkForce true);

    boot = {
      initrd.kernelModules = [ ];
      initrd.availableKernelModules = [ "ehci_pci" ];

      kernelPatches = []
        ++ optional cfg.x32abi.enable customKernelPatches.enableX32ABI
        ++ optional cfg.rtGroupSched.enable customKernelPatches.enableRTGroupSched
        ++ optional config.aviallon.optimizations.enable (customKernelPatches.optimizeForCPUArch config.aviallon.general.cpuArch)
      ;

      loader.grub.enable = cfg.useGrub;
      loader.grub = {
        version = 2;
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
  });
}
