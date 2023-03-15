{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
  myMesa = pkgs.mesa;
in {
  options.aviallon.hardware.amd = {
    enable = mkEnableOption "AMD gpus";
    useProprietary = mkEnableOption "Use proprietary AMDGPU Pro";
    defaultVulkanImplementation = mkOption {
      description = "Wether to use RADV or AMDVLK by default";
      type = with types; enum [ "amdvlk" "radv" ];
      default = "radv";
    };
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

      "amdgpu.ppfeaturemask" = mkIf generalCfg.unsafeOptimizations "0xfff7ffff";
      "amdgpu.freesync_video" = 1;
      #"amdgpu.mes" = mkIf generalCfg.unsafeOptimizations 1;
    };

    environment.systemPackages = with pkgs; []
      ++ [
        rocm-smi
      ]
      ++ optionals devCfg.enable ([]
        ++ [ rocminfo ]
      )
    ;

    services.xserver.videoDrivers = []
    ++ optional cfg.useProprietary "amdgpu-pro"
    ++ [
      "amdgpu"
      "radeon"
    ];

    programs.corectrl.enable = mkIf generalCfg.unsafeOptimizations true;

    hardware.opengl = {
      enable = true;
      package = with pkgs; myMesa.drivers;
      extraPackages = with pkgs; mkIf (!cfg.useProprietary) (mkAfter [
        rocm-opencl-icd
        rocm-opencl-runtime
        (hiPrio myMesa)
        amdvlk
      ]);
      extraPackages32 = with pkgs.driversi686Linux; mkIf (!cfg.useProprietary) [
        mesa
        amdvlk
      ];
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
