{ config, pkgs, lib, options, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
  generalCfg = config.aviallon.general;
  hardwareCfg = config.hardware;
  toValue = x: if x then "1" else "0";
  xwaylandEGLStream = pkgs.writeShellScriptBin "xwayland" ''
    exec ${options.programs.xwayland.package.default}/bin/xwayland -eglstream "$@"
  '';
in {
  options = {
    aviallon.hardware.nvidia.proprietary = {
      #enable = mkEnableOption "Wether to user NVidia proprietary drivers";
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
    };
  };
  
  config = mkIf (cfg.enable && cfg.useProprietary) {

    assertions = [];
  
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_drm"
      "nvidia_uvm"
      "nvidia_modeset"
    ];

    services.xserver.videoDrivers = [
      "nvidia"
    ];

    services.xserver.screenSection = ''
    Option "Coolbits" "${toString cfg.proprietary.coolbits}"
    Option "InbandStereoSignaling" "true"
    '';

    services.xserver.exportConfiguration = true;

    hardware.nvidia = {
      powerManagement = mkIf (config.hardware.nvidia.prime.offload.enable || cfg.proprietary.saveAllVram) {
        enable = true;
        finegrained = true;
      };
      modesetting.enable = true;
      nvidiaSettings = true;
    };

    aviallon.hardware.nvidia.proprietary.EGLStream = mkDefault (
      versionOlder hardwareCfg.nvidia.package.version "490.29.05" # https://www.nvidia.com/download/driverResults.aspx/181159/en-us/
    );

    aviallon.programs.nvtop.nvidia = true;

    aviallon.boot.cmdline = {}
      // {
        "nvidia-drm.modeset" = 1;
        "nvidia.NVreg_UsePageAttributeTable" = 1;
      }
      // {
        "nvidia.NVreg_PreserveVideoMemoryAllocations" = toValue cfg.proprietary.saveAllVram;
        "nvidia.NVreg_TemporaryFilePath" = "/var/tmp/nvidia-gpu.vram.img";
      }
    ;

    programs.xwayland.package = mkIf cfg.proprietary.EGLStream xwaylandEGLStream;
    aviallon.programs.allowUnfreeList = [
      "nvidia-x11"
      "nvidia-settings"
      "cudatoolkit"
    ];

    hardware.opengl.extraPackages = with pkgs; [
      nvidia-vaapi-driver
      libvdpau-va-gl
      vaapiVdpau
    ];

    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
      libvdpau-va-gl
      vaapiVdpau
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
      "__GL_THREADED_OPTIMIZATIONS" = toValue generalCfg.unsafeOptimizations;
      "KWIN_DRM_USE_EGL_STREAMS" = toValue cfg.proprietary.EGLStream; # Make KWin use EGL Streams if needed, because otherwise performance will be horrible.
    };
  };
}
