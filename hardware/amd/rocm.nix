{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  localCfg = config.aviallon.hardware.amd.rocm;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;

  gfxToCompatibleMap = {
    gfx900 = "9.0.0";
    gfx902 = "9.0.0";
    gfx904 = "9.0.0";
    gfx909 = "9.0.0";
    gfx90c = "9.0.0";
    gfx1011 = "10.1.0";
    gfx1012 = "10.1.0";
    gfx1031 = "10.3.0";
    gfx1032 = "10.3.0";
    gfx1033 = "10.3.0";
    gxf1034 = "10.3.0";
    gxf1035 = "10.3.0";
    gxf1036 = "10.3.0";
  };

  /*autoDetectGPU = pkgs: pkgs.callPackage (
    { runCommandLocal,
      gnugrep,
      rocmPackages,
    }: runCommandLocal "hsa-version" { nativeBuildInputs = [ gnugrep rocmPackages.rocminfo ]; } ''
        set +e
        mkdir -p $out/
        echo "Computing HSA version" &>/dev/stderr
        ls -l /dev/kfd
        rocminfo &>/dev/stderr
        rocminfo | grep --only-matching --perl-regexp '^\s*Name:\s+\Kgfx[0-9a-f]+' | tee $out/output
       ''
  ) { };*/

  gfxToCompatible = gfxISA: if (hasAttr gfxISA gfxToCompatibleMap) then (getAttr gfxISA gfxToCompatibleMap) else "";
in {

  options.aviallon.hardware.amd.rocm = {
    enable = (mkEnableOption "ROCm configuration") // { default = true; };
    gfxISA = mkOption {
      description = "What is the GFX ISA of your system. Leave blank if you have several GPUs of incompatible ISAs";
      default = "";
      example = "gfx902";
      type = types.string;
    };
    gpuTargets = mkOption {
      description = "Override supported GPU ISAs in some ROCm packages.";
      default = [ "803"
                "900"
                "906:xnack-"
                "908:xnack-"
                "90a:xnack+" "90a:xnack-"
                "940"
                "941"
                "942"
                "1010"
                "1012"
                "1030"
                "1031"
                "1100"
                "1101"
                "1102" ];
      example = [ "900" "1031" ];
      type = with types; nullOr (listOf string);
    };
  };

  config = mkIf (cfg.enable && localCfg.enable) {  
    environment.systemPackages = with pkgs;
      [
        rocmPackages.rocm-smi
        #rocmPackages.meta.rocm-ml-libraries
        rocmPackages.meta.rocm-hip-runtime

        #pkgs.autoDetectGPU
      ] ++ optionals devCfg.enable [
        rocmPackages.rocminfo
      ]
    ;

    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.meta.rocm-hip-runtime}"
      #"L+    /tmp/hsa-version - - - - ${pkgs.autoDetectGPU}"
    ];

    environment.variables = {
      ROC_ENABLE_PRE_VEGA = "1"; # Enable OpenCL with Polaris GPUs  
    } // (mkIf (gfxToCompatible cfg.rocm.gfxISA != "") {
      HSA_OVERRIDE_GFX_VERSION = gfxToCompatible cfg.rocm.gfxISA;
    });

    # Make rocblas and rocfft work
    nix.settings.extra-sandbox-paths = [
      "/dev/kfd?"
      "/sys/devices/virtual/kfd?"
      "/dev/dri/renderD128?"
    ];

    nix.settings.substituters = [ "https://nixos-rocm.cachix.org" ];
    nix.settings.trusted-public-keys = [ "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE=" ];

    nixpkgs.config.rocmSupport = true;

    nixpkgs.overlays = mkBefore [(final: prev: {
        rocmPackages = prev.rocmPackages // {
          clr = prev.rocmPackages.clr.overrideAttrs (oldAttrs: {
            passthru = oldAttrs.passthru // {
              # We cannot use this for each ROCm library, as each defines their own supported targets
              # See: https://github.com/ROCm/ROCm/blob/77cbac4abab13046ee93d8b5bf410684caf91145/README.md#library-target-matrix
              gpuTargets = lib.forEach localCfg.gpuTargets (target: "gfx${target}");
            };
          });

          rocblas = prev.rocmPackages.rocblas.override {
            gpuTargets = lib.forEach localCfg.gpuTargets (target: "gfx${target}");
          };
        };
    })];
  };
}
