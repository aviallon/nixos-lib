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
  };
}
