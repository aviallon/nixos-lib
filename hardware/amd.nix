{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in
{
  options.aviallon.hardware.amd = {
    enable = mkEnableOption "AMD gpus";
    useProprietary = mkEnableOption "Use proprietary AMDGPU Pro";
  };
  
  config = mkIf (cfg.enable) {
    boot.initrd.kernelModules = [ "amdgpu" ];

    aviallon.boot.cmdline = {
      # for Southern Islands (SI ie. GCN 1) cards
      "radeon.si_support" = 0;
      "amdgpu.si_support" = 1;
      # for Sea Islands (CIK ie. GCN 2) cards
      "radeon.cik_support" = 0;
      "amdgpu.cik_support" = 1;
      "amdgpu.freesync_video" = 1;
      "amdgpu.mes" = mkIf generalCfg.unsafeOptimizations 1;
    };

    environment.systemPackages = with pkgs; []
      ++ [
        rocm-smi
      ]
      ++ optionals devCfg.enable ([]
        ++ [ rocminfo ]
        ++ optional (hasAttr "hipify-perl" pkgs) pkgs.hipify-perl
        ++ optional (hasAttr "tensorflow2-rocm" pkgs) pkgs.tensorflow2-rocm
      )
    ;

    services.xserver.videoDrivers = []
    ++ optional cfg.useProprietary "amdgpu-pro"
    ++ [
      "amdgpu"
      "radeon"
    ];

    hardware.opengl.enable = true;
    hardware.opengl.extraPackages = with pkgs; mkIf (!cfg.useProprietary) [
      rocm-opencl-icd
      rocm-opencl-runtime
      amdvlk
    ];

    hardware.opengl.extraPackages32 = with pkgs.driversi686Linux; mkIf (!cfg.useProprietary) [
      amdvlk
      mesa
    ];

    # Make rocblas and rocfft work
    nix.settings.extra-sandbox-paths = [
      "/dev/kfd?"
      "/sys/devices/virtual/kfd?"
      "/dev/dri/renderD128?"
    ];
  };
}
