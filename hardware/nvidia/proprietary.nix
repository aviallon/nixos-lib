{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in {
    config = mkIf (cfg.enable && cfg.useProprietary) {
      boot.initrd.kernelModules = [
        "nvidia"
        "nvidia_drm"
        "nvidia_uvm"
        "nvidia_modeset"
      ];
      # boot.blacklistedKernelModules = [ "nouveau" ];
      services.xserver.videoDrivers = [
        "nvidia"
      ];

      hardware.nvidia = {
        powerManagement.enable = true;
        powerManagement.finegrained = ifEnable config.hardware.nvidia.prime.offload.enable true;
        modesetting.enable = true;
        #package = with config.boot.kernelPackages.nvidiaPackages;
        #  if (cfg.driver == "stable") then
        #    stable
        #  else if (cfg.driver == "390") then
        #    legacy_390
        #  else if (cfg.driver == "340") then
        #    legacy_340
        # else
        #    null
        #  ;
      };
      services.xserver.displayManager.gdm.nvidiaWayland = mkDefault true;

      aviallon.boot.cmdline = mkIf cfg.saveAllVram {
        NVreg_PreserveVideoMemoryAllocations = 1;
        NVreg_TemporaryFilePath = "/tmp/nvidia-gpu.vram.img";
      };

      aviallon.programs.allowUnfreeList = [
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
      environment.variables = {
        "__GL_YIELD" = "USLEEP"; # use usleep(0) instead of sched_yield() -> better performance in most cases
        "__GL_ALLOW_UNOFFICIAL_PROTOCOL" = "1"; # allow unofficial GLX protocol if also set in Xorg conf
        "__GL_VRR_ALLOWED" = "1"; # Try to enable G-SYNC VRR if screen AND app is compatible
      };
    };
}
