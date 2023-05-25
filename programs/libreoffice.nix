{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.programs.libreoffice;
  toStringOrFunc = x:
    if isFunction x
    then "<function>"
    else (builtins.toJSON x)
  ;
  applyOverrides = overrides: pkg:
    foldl'
      (prev: override:
        let
          r = (trace "override: ${toStringOrFunc override}" override) (trace "prev: ${toString prev}" prev);
        in trace "result: ${toString r}" r
      )
    pkg
    overrides
  ;
in {
  options.aviallon.programs.libreoffice = {
    enable = mkEnableOption "LibreOffice";
    variant = mkOption {
      type = with types; types.enum [ "still" "fresh" ];
      default = "fresh";
      description = "Which LibreOffice variant to use";
    };
    qt = mkEnableOption "Qt support";
    gnome = mkOption {
      description = "Wether to enable Gnome support";
      default = true;
      type = types.bool;
      internal = true;
    };
    opencl = mkEnableOption "OpenCL support";
    package = mkOption {
      description = "Which final LibreOffice package to use";
      type = myLib.types.package';
    };
    package' = mkOption {
      internal = true;
      description = "Which base (unwrapped) LibreOffice package to use";
      default = if cfg.qt then pkgs.libreoffice-qt.unwrapped else pkgs.libreoffice.unwrapped;
      type = myLib.types.package';
    };
  };

  config = mkIf cfg.enable {
    aviallon.programs.libreoffice.package =
      let
        overridesList = []
          ++ [(pkg: pkg.override {
              variant = cfg.variant;
            })]
          ++ optional cfg.opencl (pkg: pkg.overrideAttrs (old: {
              buildInputs = old.buildInputs ++ [ pkgs.ocl-icd ];
            }))
        ;
      in pkgs.libreoffice.override {
          unwrapped = applyOverrides overridesList cfg.package';
        };
        

    environment.systemPackages = [
      cfg.package
    ];
  };
}
