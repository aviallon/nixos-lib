{ config, pkgs, lib, ... }:
with lib;
let
  hardwareCfg = config.aviallon.hardware;
in
{
  config = mkIf (hardwareCfg.gpuVendor == "intel") {
    boot.initrd.kernelModules = [ "i915" ];
    hardware.opengl = {
      enable = true;
      extraPackages = with pkgs; [
  #      intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        libvdpau-va-gl

        intel-graphics-compiler
        intel-compute-runtime
      ];
    };
  };
}
