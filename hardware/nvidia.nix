{ config, pkgs, lib, ... }:
with lib;
let
  hardwareCfg = config.aviallon.hardware;
in
{
  imports = [
    ./nvidia
  ];

  options.aviallon.hardware.useProprietary = mkEnableOption "nvidia proprietary drivers";

  config = mkIf (hardwareCfg.gpuVendor == "nvidia") {
    boot.initrd.kernelModules = if hardwareCfg.useProprietary then [
      "nvidia"
      "nvidia_drm"
      "nvidia_uvm"
      "nvidia_modeset"
    ] else [ "nouveau" ];
    # boot.blacklistedKernelModules = optional hardwareCfg.useProprietary "nouveau";
    services.xserver.videoDrivers = optional hardwareCfg.useProprietary "nvidia";
    hardware.opengl.driSupport32Bit = true;
    hardware.nvidia = {
      powerManagement.enable = true;
      modesetting.enable = true;
    };

    nixpkgs.config.allowUnfreePredicate = mkIf (hardwareCfg.useProprietary) (pkg: builtins.elem (lib.getName pkg) [
        "nvidia-x11"
    ]);

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
