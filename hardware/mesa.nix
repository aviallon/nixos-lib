{ config, pkgs, lib, options, ... }:
with lib;
let
  cfg = config.aviallon.hardware.mesa;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
  optimizationsCfg = config.aviallon.optimizations;
  optimizePkg = optimizationsCfg.optimizePkg;
  packageWithDefaults = types.package // {
    merge = loc: defs:
      let res = mergeDefaultOption loc defs;
      in if builtins.isPath res || (builtins.isString res && ! builtins.hasContext res)
        then toDerivation res
        else res;
  };
in {
  options.aviallon.hardware.mesa = {
    enable = mkOption {
      default = false;
      type = types.bool;
      description = "Wether to enable mesa specific configuration";
      example = true;
    };
    optimized = mkOption {
      default = generalCfg.unsafeOptimizations;
      type = types.bool;
      description = "Wether to enable (unsafe) mesa optimizations";
      example = false;
    };
    unstable = mkOption {
      default = false;
      type = types.bool;
      internal = true;
      description = "Wether or not to use mesa from nixpkgs-unstable [BROKEN]";
      example = config.aviallon.general.unsafeOptimizations;
    };
    package = mkOption {
      default = pkgs.mesa;
      type = packageWithDefaults;
      description = "What mesa package to use";
    };
    package32 = mkOption {
      default = pkgs.driversi686Linux.mesa;
      type = packageWithDefaults;
      description = "What mesa package to use";
    };

    internal.package = mkOption {
      internal = true;
      type = packageWithDefaults;
      default = cfg.package;
    };
    
    internal.package32 = mkOption {
      internal = true;
      type = packageWithDefaults;
      default = cfg.package32;
    };
  };

  config = mkIf cfg.enable {
    programs.corectrl.enable = mkDefault config.hardware.graphics.enable;

    aviallon.hardware.mesa.package = mkIf cfg.unstable pkgs.unstable.mesa;
    aviallon.hardware.mesa.package32 = mkIf cfg.unstable pkgs.unstable.driversi686Linux.mesa;

    aviallon.hardware.mesa.internal = mkIf cfg.optimized {
      package = mkDefault (
        optimizePkg { lto = false; } cfg.package);
      package32 = mkDefault (
        optimizePkg { lto = false; } cfg.package32);
    };

    hardware.graphics = {
      package = with pkgs; cfg.internal.package;
      package32 = with pkgs; cfg.internal.package32;

      extraPackages = optional (hasAttr "opencl" cfg.internal.package.out) cfg.internal.package.out.opencl;
      extraPackages32 = optional (hasAttr "opencl" cfg.internal.package32.out) cfg.internal.package32.out.opencl;
    };

    # Warning: mesa has many outputs, and "opencl" is not in "drivers"
    # See pkgs.mesa.outputs

    environment.variables = {
      VAAPI_MPEG4_ENABLED = "1"; # https://docs.mesa3d.org/envvars.html#va-api-environment-variables
    };
  };
}
