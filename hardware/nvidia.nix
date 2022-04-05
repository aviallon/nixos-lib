{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware;
in
{
  imports = [
    ./nvidia
  ];

  options.aviallon.hardware.useProprietary = mkEnableOption "nvidia proprietary drivers";

  config = mkIf (cfg.gpuVendor == "nvidia") {
    boot.initrd.kernelModules = if cfg.useProprietary then [
      "nvidia"
      "nvidia_drm"
      "nvidia_uvm"
      "nvidia_modeset"
    ] else [ "nouveau" ];
    # boot.blacklistedKernelModules = optional cfg.useProprietary "nouveau";
    services.xserver.videoDrivers = optional cfg.useProprietary "nvidia";
    hardware.opengl.driSupport32Bit = true;
    hardware.nvidia = {
      powerManagement.enable = true;
      modesetting.enable = true;
    };

    aviallon.programs.allowUnfreeList = mkIf (cfg.useProprietary) [
        "nvidia-x11"
        "nvidia-settings"
    ];

    hardware.opengl.extraPackages = with pkgs; [
      libvdpau-va-gl
      vaapiVdpau
    ];
    
    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [
      libvdpau-va-gl
      vaapiVdpau
    ];

    # See documentation here: https://download.nvidia.com/XFree86/Linux-x86_64/510.60.02/README/openglenvvariables.html
    environment.variables = ifEnable cfg.useProprietary {
      "__GL_YIELD" = "USLEEP"; # use usleep(0) instead of sched_yield() -> better performance in most cases
      "__GL_ALLOW_UNOFFICIAL_PROTOCOL" = "1"; # allow unofficial GLX protocol if also set in Xorg conf
      "__GL_VRR_ALLOWED" = "1"; # Try to enable G-SYNC VRR if screen AND app is compatible
    };
  };
}
