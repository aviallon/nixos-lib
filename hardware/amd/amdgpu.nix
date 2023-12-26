{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in {
  config = mkIf (cfg.enable && cfg.kernelDriver == "amdgpu") {
    boot.initrd.kernelModules = [ "amdgpu" ];

    aviallon.boot.cmdline = {
      # for Southern Islands (SI ie. GCN 1) cards
      "radeon.si_support" = 0;
      "amdgpu.si_support" = 1;
      # for Sea Islands (CIK ie. GCN 2) cards
      "radeon.cik_support" = 0;
      "amdgpu.cik_support" = 1;

      "amdgpu.ppfeaturemask" = mkIf generalCfg.unsafeOptimizations "0xfff7ffff";
      "amdgpu.freesync_video" = 1;
      #"amdgpu.mes" = mkIf generalCfg.unsafeOptimizations 1;
    };

    environment.systemPackages = with pkgs; []
      ++ [ rocm-smi ]
      ++ optionals devCfg.enable [
        rocminfo
      ]
    ;

    nixpkgs.config.rocmSupport = mkDefault devCfg.enable;

    services.xserver.videoDrivers = []
    ++ optional cfg.useProprietary "amdgpu-pro"
    ++ [
      "amdgpu"
    ];

    hardware.opengl = {
      enable = true;
      extraPackages = with pkgs; mkIf (!cfg.useProprietary) (
        [
          rocm-opencl-icd
          rocm-opencl-runtime
        ]
        ++ optional (cfg.defaultVulkanImplementation == "amdvlk") amdvlk
      );
      extraPackages32 = with pkgs.driversi686Linux; mkIf (!cfg.useProprietary) ([]
        ++ optional (cfg.defaultVulkanImplementation == "amdvlk") amdvlk
      );
    };

    environment.variables = {
      "AMD_VULKAN_ICD" = strings.toUpper cfg.defaultVulkanImplementation;
    };

    # Make rocblas and rocfft work
    nix.settings.extra-sandbox-paths = [
      "/dev/kfd?"
      "/sys/devices/virtual/kfd?"
      "/dev/dri/renderD128?"
    ];
  };
}
