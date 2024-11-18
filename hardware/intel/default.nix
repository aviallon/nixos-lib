{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.intel;
  generalCfg = config.aviallon.general;
  laptopCfg = config.aviallon.laptop;
  devCfg = config.aviallon.developer;
in
{
  options.aviallon.hardware.intel = {
    enable = mkEnableOption "Intel GPUs";
    iHD = mkEnableOption "Use iHD driver instead of i965";
  };

  imports = [
    ./cpu.nix
  ];
  
  config = mkIf cfg.enable {
    aviallon.programs.nvtop = {
      enable = true;
      backend = [ "intel" ];
    };
  
    boot.initrd.kernelModules = [ "i915" ];
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; []
        ++ [
          vaapiVdpau
          libvdpau-va-gl

          intel-graphics-compiler
          intel-compute-runtime
        ]
        ++ optional cfg.iHD intel-media-driver # LIBVA_DRIVER_NAME=iHD
        ++ optional (!cfg.iHD) vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      ;
    };

    aviallon.boot.cmdline = {}
    // optionalAttrs generalCfg.unsafeOptimizations {
      "i915.mitigations" = "off";
      "i915.enable_fbc" = 1;
    }
    // optionalAttrs laptopCfg.enable {
      "i915.enable_fbc" = 1;
      "i915.enable_dc" = 4;
    }
    // optionalAttrs (generalCfg.unsafeOptimizations && laptopCfg.enable) {
      "i915.enable_psr" = 1;
    }
    // optionalAttrs devCfg.enable {
      "i915.enable_gvt" = 1;
    }
    // {
      "i915.fastboot" = 1;
    };
    aviallon.hardware.mesa.enable = mkDefault true;
  };
}
