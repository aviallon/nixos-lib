{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.mesa;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
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
    package = mkOption {
      internal = true;
      default = pkgs.mesa;
      type = packageWithDefaults;
      description = "What mesa package to use";
    };
    package32 = mkOption {
      internal = true;
      default = pkgs.driversi686Linux.mesa;
      type = packageWithDefaults;
      description = "What mesa package to use";
    };
  };

  config = mkIf cfg.enable {
    programs.corectrl.enable = mkDefault config.hardware.opengl.enable;

    aviallon.hardware.mesa.package = mkIf cfg.optimized pkgs.mesaOptimized;
    #aviallon.hardware.mesa.package32 = mkIf (mkDefault cfg.optimized pkgs.driversi686Linux.mesaOptimized);

    hardware.opengl = {
      package = with pkgs; cfg.package.drivers;
      package32 = with pkgs; cfg.package32.drivers;
    };
  };
}
