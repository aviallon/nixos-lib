{ config, pkgs, lib, options, nixpkgs-unstable, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
  generalCfg = config.aviallon.general;
  hardwareCfg = config.hardware;
  toValue = x: if x then "1" else "0";
  xwaylandEGLStream = pkgs.writeShellScriptBin "xwayland" ''
    exec ${options.programs.xwayland.package.default}/bin/xwayland -eglstream "$@"
  '';

  nvidiaUnstable = config.boot.kernelPackages.callPackage (nixpkgs-unstable + /pkgs/os-specific/linux/nvidia-x11/default.nix) {};
in {
  options = {
    aviallon.hardware.nvidia.proprietary = {
      gsync = mkEnableOption "Screen is GSYNC monitor";
      vsync = mkOption {
        description = "Wether to enable or disable vsync";
        default = true;
        example = false;
        type = types.bool;
      };
      coolbits = mkOption {
        description = "Coolbits value. Used for enabling hidden (dangerous) features";
        default = if generalCfg.unsafeOptimizations then 28 else 5;
        example = 28;
        type = types.int;
      };
      EGLStream = mkOption {
        description = "Wether to make some packages use EGLStream instead of GBM when using Wayland";
        example = true;
        default = false;
        defaultText = literalExpression ''
          versionOlder config.hardware.nvidia.package.version "490.29.05"; # https://www.nvidia.com/download/driverResults.aspx/181159/en-us/
        '';
        type = types.bool;
      };
      saveAllVram = mkEnableOption "back up all VRAM in /var/tmp before going to sleep. May reduce artifacts after resuming";
      version = mkOption {
        description = "What Nvidia version variant to use";
        type = types.enum [ "production" "stable" "beta" "unstable_beta" ];
        default = if generalCfg.unsafeOptimizations then "beta" else "stable";
        example = "unstable_beta";
      };
    };
  };
  
  config = mkIf (cfg.enable && cfg.variant == "proprietary") {

    assertions = [];
  
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      # "nvidia_uvm" # Don't load it early as it causes power-management issues
    ];

    services.xserver.videoDrivers = [
      "nvidia"
    ];

    services.xserver.screenSection = ''
    Option "Coolbits" "${toString cfg.proprietary.coolbits}"
    Option "InbandStereoSignaling" "true"
    '';

    services.xserver.exportConfiguration = true;

    services.xserver.displayManager.sddm.wayland.enable = false; # Frequent issues with Nvidia GPUs

    hardware.nvidia = {
      powerManagement = mkIf (config.hardware.nvidia.prime.offload.enable || cfg.proprietary.saveAllVram) {
        enable = true;
        finegrained = mkIf config.hardware.nvidia.prime.offload.enable true;
      };
      modesetting.enable = true;
      nvidiaSettings = true;
      package =
        if cfg.proprietary.version == "unstable_beta" then
          nvidiaUnstable.beta # Use bleeding edge version
        else
          config.boot.kernelPackages.nvidiaPackages.${cfg.proprietary.version}
        ;
    };

    aviallon.hardware.nvidia.proprietary.EGLStream = mkDefault (
      versionOlder hardwareCfg.nvidia.package.version "490.29.05" # https://www.nvidia.com/download/driverResults.aspx/181159/en-us/
    );

    aviallon.programs.nvtop.nvidia = true;

    aviallon.boot.cmdline = {}
      // {
        "nvidia-drm.modeset" = 1;
        "nvidia.NVreg_UsePageAttributeTable" = 1;
        "nvidia.NVreg_InitializeSystemMemoryAllocations" = 0;
      }
      // optionalAttrs cfg.proprietary.saveAllVram {
        # "nvidia.NVreg_PreserveVideoMemoryAllocations" = 1; # Already setby hardware.nvidia.powerManagement.enable
        "nvidia.NVreg_DynamicPowerManagement" = "0x02";
        "nvidia.NVreg_EnableS0ixPowerManagement" = 1;
        "nvidia.NVreg_TemporaryFilePath" = "/var/tmp";
      }
    ;

    programs.xwayland.package = mkIf cfg.proprietary.EGLStream xwaylandEGLStream;
    aviallon.programs.allowUnfreeList = [
      "nvidia-x11"
      "nvidia-settings"
      
      "cudatoolkit"
      "cuda_cccl"
      "libnpp"
      "libcublas"
      "libcufft"
      "cuda_cudart"
      "cuda_nvcc"
      "cudnn-8.6.0.163"
      "cudnn"
      "cuda_nvml_dev"
    ];

    # Causes massive rebuilds (tensorflow, openCV, etc.), will need to find a better cache beforehand
    # For now, prefer using package overrides
    # nixpkgs.config.cudaSupport = mkDefault true;

    hardware.opengl.extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];

    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
    ];

    environment.systemPackages = with pkgs; [
      nvtop
    ];

    # See documentation here: https://download.nvidia.com/XFree86/Linux-x86_64/510.60.02/README/openglenvvariables.html
    environment.variables = {
      "__GL_YIELD" = "USLEEP"; # use usleep(0) instead of sched_yield() -> better performance in most cases
      "__GL_ALLOW_UNOFFICIAL_PROTOCOL" = "1"; # allow unofficial GLX protocol if also set in Xorg conf
      "__GL_VRR_ALLOWED" = "1"; # Try to enable G-SYNC VRR if screen AND app is compatible
      "__GL_SYNC_TO_VBLANK" = toValue cfg.proprietary.vsync; 

      # Causes Kwin to fail
      # https://github.com/ValveSoftware/gamescope/issues/526#issuecomment-1733739097
      __GL_THREADED_OPTIMIZATIONS = "0";
      # "__GL_THREADED_OPTIMIZATIONS" = toValue generalCfg.unsafeOptimizations;
      "KWIN_DRM_USE_EGL_STREAMS" = toValue cfg.proprietary.EGLStream; # Make KWin use EGL Streams if needed, because otherwise performance will be horrible.


      # Undocumented, fix for EGL not being found by Nvidia driver: https://github.com/NVIDIA/egl-wayland/issues/39#issuecomment-927288015
      __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS = "/run/opengl-driver/share/egl/egl_external_platform.d";
    };
  };
}
