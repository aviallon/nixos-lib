{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.intel;
in
{
  options.aviallon.hardware.intel = {
    enable = mkEnableOption "Intel GPUs";
  };
  
  config = mkIf cfg.enable {
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
