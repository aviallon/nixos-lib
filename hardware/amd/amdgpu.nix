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
      #"amdgpu.mes" = mkIf generalCfg.unsafeOptimizations 1;
      "amdgpu.seamless" = mkIf generalCfg.unsafeOptimizations 1;
    };

    environment.systemPackages = with pkgs; []
      ++ [ rocmPackages.rocm-smi ]
      ++ optionals devCfg.enable [
        rocmPackages.rocminfo
      ]
    ;

    aviallon.programs.config.rocmSupport = mkDefault devCfg.enable;

    services.xserver.videoDrivers = 
      optional cfg.useProprietary "amdgpu-pro"
      ++ [ "modesetting" ];

    hardware.amdgpu.opencl.enable = true;

    hardware.amdgpu.amdvlk.enable = cfg.defaultVulkanImplementation == "amdvlk";
    hardware.amdgpu.amdvlk.support32Bit.enable = mkDefault config.hardware.amdgpu.amdvlk.enable;

    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];

    environment.variables = {
      AMD_VULKAN_ICD = mkIf (cfg.defaultVulkanImplementation == "amdvlk") (strings.toUpper cfg.defaultVulkanImplementation);
      ROC_ENABLE_PRE_VEGA = "1"; # Enable OpenCL with Polaris GPUs
    };

    # Make rocblas and rocfft work
    nix.settings.extra-sandbox-paths = [
      "/dev/kfd?"
      "/sys/devices/virtual/kfd?"
      "/dev/dri/renderD128?"
    ];

    nix.settings.substituters = [ "https://nixos-rocm.cachix.org" ];
    nix.settings.trusted-public-keys = [ "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE=" ];

    nixpkgs.overlays = [(final: prev: {
        # Overlay Blender to use the HIP build if we have a compatible AMD GPU
        blender = final.blender-hip;
        blender-prev = prev.blender;
      })];
  };
}
