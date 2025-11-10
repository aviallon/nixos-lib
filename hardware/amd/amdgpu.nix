{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in {
  config = mkIf (cfg.enable && cfg.kernelDriver == "amdgpu") {  
    boot.initrd.kernelModules = [ "amdgpu" ];

    hardware.amdgpu.legacySupport.enable = true;

    aviallon.boot.cmdline = {
      "amdgpu.ppfeaturemask" = mkIf generalCfg.unsafeOptimizations "0xfff7ffff";
      #"amdgpu.mes" = mkIf generalCfg.unsafeOptimizations 1;
      "amdgpu.seamless" = mkIf generalCfg.unsafeOptimizations 1;
    };

    aviallon.programs.config.rocmSupport = mkDefault devCfg.enable;

    services.udev.extraRules = mkAfter ''
      SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power_dpm_force_performance_level}="auto"
    '';

    services.xserver.videoDrivers = 
      optional cfg.useProprietary "amdgpu-pro"
      ++ [ "modesetting" ];

    hardware.amdgpu.opencl.enable = true;

    environment.variables = {
      ROC_ENABLE_PRE_VEGA = "1"; # Enable OpenCL with Polaris GPUs
    };

  };
}
