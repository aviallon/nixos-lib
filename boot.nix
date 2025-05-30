{ config, pkgs, lib, myLib, options, ... }:
with lib;
let
  customKernelPatches = {
    zstd = {
      name = "zstd";
      patch = null;
      extraConfig = ''
        MODULE_COMPRESS_XZ n
        MODULE_COMPRESS_ZSTD y
        ZSWAP_COMPRESSOR_DEFAULT_ZSTD y
        #ZSWAP_ZPOOL_DEFAULT_Z3FOLD y # Use more-efficient z3fold by default (especially useful with Zstd which has a high compression ratio.)
        FW_LOADER_COMPRESS_ZSTD y
        ZRAM_DEF_COMP_ZSTD y
      '';
    };
  
    enableX32ABI = {
      name = "enable-x32";
      patch = null;
      extraConfig = ''
        X86_X32_ABI y
      '';
    };
    enableRTGroupSched = {
      name = "enable-rt-group-sched";
      patch = null;
      extraConfigStructuredConfig = with lib.kernel; {
        RT_GROUP_SCHED = yes;
      };
    };
    enableEnergyModel = {
      name = "enable-energy-model";
      patch = null; extraStructuredConfig = with lib.kernel; {
        ENERGY_MODEL = yes;
      };
    };
    removeKernelDRM = {
      name = "remove-kernel-drm";
      patch = ./remove-kernel-drm.patch;
    };

    
    backports = {
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
        if (isNull value) then
          null
        else if (value == "") then
          "${key}"
        else
          "${key}=${toCmdlineValue value}"
      ) set;

  isXanmod = kernel: ! isNull (strings.match ".*(xanmod).*" kernel.modDirVersion);

  kernelVersionOlder = ver: versionOlder cfg.kernel.package.version ver;
  
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

    
    x32abi.enable = mkEnableOption "X32 kernel ABI";
    kvdo.enable = mkEnableOption "dm-kvdo kernel module";
    rtGroupSched.enable = mkEnableOption "RT cgroups"; # Breaks standard way of setting RT sched policy to processes
    energyModel.enable = mkEnableOption "Energy Model";
    
    patches = {
      amdClusterId.enable = mkEnableOption "Energy Model";
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

    cmdline = mkOption {
      description = "Kernel params as attributes (instead of list). Set a parameter to `null` to remove it.";
      default = { };
      example = { "i915.fastboot" = true; };
      type = with types; lazyAttrsOf (
        nullOr (
          oneOf [ bool int str (listOf str) ]
        )
      );
    };

    kernel = {
      package = mkOption {
        description = "Linux kernel to use";
        default = options.boot.kernelPackages.default.kernel;
        example = "pkgs.kernel";
        type = myLib.types.package';
      };

      addAttributes = mkOption {
        description = "Merge specified attributes to kernel derivation (via special overideAttrs)";
        default = {};
        type = with types; attrs;
        example = { KCFLAGS = "-Wall"; };
      };

      addOptimizationAttributes = mkOption {
        description = "Merge specified attributes to kernel derivation IF aviallon.optimizations.enabled is true";
        default = {};
        type = with types; attrs;
        example = { KCFLAGS = "-O3 -fipa-pta"; };
      };
    };

    removeKernelDRM = mkEnableOption "convert all EXPORT_SYMBOL_GPL to EXPORT_SYMBOL. Warning: might be illegal in your region.";
  };

  imports = [
    ( mkRemovedOptionModule  [ "aviallon" "boot" "extraKCflags" ] "Replaced by aviallon.boot.kernel.addOptimizationAttributes attrset" )
    ( mkRemovedOptionModule  [ "aviallon" "boot" "loops_per_jiffies" ] "Actually unused by the kernel" )
  ];

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

    boot.kernelParams = filter (v: ! (isNull v)) (toCmdlineList cfg.cmdline);
  } 
  (mkIf cfg.enable {
  
    hardware.enableAllFirmware = allowUnfree;
    hardware.enableRedistributableFirmware = true;

    aviallon.boot.cmdline = {
      "syscall.x32" = mkIf cfg.x32abi.enable true;

      # Reboot after 5 seconds on panic (prevent system lockup)
      "panic" = 5;

      # From systemd(1): systemd.show_status
      # Takes a boolean argument or the constants error and auto. Can be also specified without an argument, with the same effect as a positive boolean. If enabled, the systemd manager (PID 1) shows
      # terse service status updates on the console during bootup. With error, only messages about failures are shown, but boot is otherwise quiet.  auto behaves like false until there is a significant
      # delay in boot. Defaults to enabled, unless quiet is passed as kernel command line option, in which case it defaults to error.
      "systemd.show_status" =
        if config.boot.consoleLogLevel <= 1 then
          "no"
        else if config.boot.consoleLogLevel < 4 then
          "error"
        else if config.boot.consoleLogLevel == 4 then
          "auto"
        else
          "yes"
        ;

      # 'quiet' is required to silence systemd-efi-stub messages
      "quiet" = mkIf (config.boot.consoleLogLevel <= 4) true;
    };

    nixpkgs.overlays = [(final: prev: {
      # Use bleeding-edge linux firmware
      linux-firmware = prev.unstable.linux-firmware;
    })];

    boot = {
      bootspec.enableValidation = true;
    
      initrd.kernelModules = [ ];
      initrd.availableKernelModules = [ "ehci_pci" ];

      # Required for many features, like rootluks TPM-unlock, etc.
      initrd.systemd.enable = true;

      initrd.compressor = "zstd";
      initrd.compressorArgs = [ "-T0" "-9" ];

      kernelPackages = with myLib.debug; let
        baseKernel = traceValWithPrefix "aviallon.boot.kernel.package" cfg.kernel.package;
        
        # Possible CFLAGS source : (myLib.optimizations.makeOptimizationFlags {}).CFLAGS
        kCflags = traceValWithPrefix "kCflags" (
          [
            "-march=${cpuConfig.arch}"
            "-mtune=${cpuConfig.tune or cpuConfig.arch}"
          ]
          ++ optional (! isNull cpuConfig.caches.lastLevel ) "--param l2-cache-size=${toString cpuConfig.caches.lastLevel}"
          ++ optional (! isNull cpuConfig.caches.l1d ) "--param l1-cache-size=${toString cpuConfig.caches.l1d}"
        );
        kRustflags = traceValWithPrefix "kRustflags" (
          [
            "-Ctarget-cpu=${cpuConfig.arch}"
            "-Ctune-cpu=${cpuConfig.tune or cpuConfig.arch}"
          ]
        );
          
        optimizedKernelAttrs = traceValWithPrefix "optimizedKernelAttrs" (
          optionalAttrs config.aviallon.optimizations.enable (
            myLib.attrsets.mergeAttrsRecursive
              {
                KCFLAGS = kCflags;
                KRUSTFLAGS = kRustflags;
              }
              (traceValWithPrefix "aviallon.boot.kernel.addOptimizationAttributes" cfg.kernel.addOptimizationAttributes)
          )
        );
        moddedKernelAttrs = traceValWithPrefix "moddedKernelAttrs" (
          myLib.attrsets.mergeAttrsRecursive (traceValWithPrefix "aviallon.boot.kernel.addAttributes" cfg.kernel.addAttributes) optimizedKernelAttrs
        );

        noDRMKernel =
          if cfg.removeKernelDRM then
            baseKernel.overrideAttrs (old: {
              passthru = baseKernel.passthru;
              nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gnused ];
              postPatch = (old.postPatch or "") + ''
                sed -i -e 's/_EXPORT_SYMBOL(sym, "_gpl")/_EXPORT_SYMBOL(sym, "")/g' -e 's/__EXPORT_SYMBOL(sym, "_gpl", __stringify(ns))/__EXPORT_SYMBOL(sym, "", __stringify(ns))/g' include/linux/export.h
              '';
            })
          else
            baseKernel
          ;
          

        moddedKernel = myLib.optimizations.addAttrs noDRMKernel moddedKernelAttrs;

        #patchedKernel =
        #  if (length config.boot.kernelPatches > 0) then
        #    moddedKernel.override (old: {
        #      structuredExtraConfig = mergeAttrs [ (old.structuredExtraConfig or {}) config.boot.kernelPatches.extraStructuredConfig ];
        #    })
        #  else
        #    moddedKernel
        #  ;
           
      in mkOverride 2 (pkgs.linuxPackagesFor moddedKernel);

      kernelPatches = []
        ++ optional cfg.x32abi.enable customKernelPatches.enableX32ABI
        ++ optional cfg.rtGroupSched.enable customKernelPatches.enableRTGroupSched
        ++ optional cfg.energyModel.enable customKernelPatches.enableEnergyModel
        ++ optional (isXanmod cfg.kernel.package && config.aviallon.optimizations.enable) (customKernelPatches.optimizeForCPUArch config.aviallon.general.cpu.arch)
        ++ optional config.aviallon.optimizations.enable customKernelPatches.zstd
      ;

      # Hide boot menu for systemd-boot by default
      loader.timeout = mkIf (!cfg.useGrub) 0;

      loader.grub.enable = cfg.useGrub;
      loader.grub = {
        device = mkIf cfg.efi "nodev";
        efiSupport = cfg.efi;
        configurationLimit = cfg.configurationLimit;
        gfxpayloadBios = "keep";
      };

      loader.systemd-boot = {
        enable = cfg.efi && (!cfg.useGrub);
        configurationLimit = cfg.configurationLimit;
        consoleMode = mkDefault "max";
        extraInstallCommands = let
          efiDir = config.boot.loader.efi.efiSysMountPoint;
        in ''
          export PATH="$PATH:${getBin pkgs.coreutils-full}/bin:${getBin pkgs.gnused}/bin"
          rpath=
          generation=
          specialization=
          boot_generation_path=$(realpath /run/booted-system)  
          for path in /nix/var/nix/profiles/system-*-link; do
            rpath=$(realpath "$path")
            ok=false
            if [ "$rpath" = "$boot_generation_path" ]; then
              echo "Good path: $path"
              ok=true
            fi
            for spec in "$path"/specialisation/*; do
              if [ "$(realpath $spec)" = "$boot_generation_path" ]; then
                ok=true
                specialization="$spec"
                echo "Good specialization: $specialization"
                break
              fi
            done
            if $ok; then
              generation="''${path##*/system-}"
              generation="''${generation%%-link}"
              break
            fi
          done
          if [ -z "$generation" ]; then
            echo "Failed to find current boot's generation!"
            exit 1
          fi

          loader_entry="${efiDir}/loader/entries/nixos-generation-''${generation}.conf"
          if ! [ -z "$specialization" ]; then
            specialization_name=$(basename -- "$specialization")
            echo "Specialization is: $specialization_name"
            loader_entry="${efiDir}/loader/entries/nixos-generation-''${generation}-specialisation-''${specialization_name}.conf"
          fi
          
          if ! [ -f "$loader_entry" ]; then
            echo "Failed to find corresponding loader generation entry:" ''${loader_entry} "not found"
            echo -e "\e[33mWARNING:\e[0m This may mean that your aviallon.boot.configurationLimit is set too low!"
            exit 1
          fi

          sed -i 's/version /version <LAST> /' "$loader_entry" &&
          echo "Marked generation $generation as last sucessfully booted"
        '';
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
