{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  _optimizeAttrs = { lto ? false , ... }@attrs:
    traceValSeq ((myLib.optimizations.makeOptimizationFlags ({
      inherit lto;
      cpuArch = generalCfg.cpuArch;
      extraCFlags = cfg.extraCompileFlags;
    } // attrs)) // {
    preConfigure = ''
      cmakeFlagsArray+=(
        "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
        "-DCMAKE_C_FLAGS=$CFLAGS"
      )
    '';
    doCheck = false;
    doInstallCheck = false;
  });
  optimizedStdenv = pkgs.addAttrsToDerivation _optimizeAttrs pkgs.fastStdenv;
  
  optimizePkg = {level ? "normal", parallelize ? null, ... }@attrs: pkg:
  (
    if (hasAttr "stdenv" pkg.override.__functionArgs) then
      trace "Optimized ${getName pkg} with stdenv at level ${level} (parallelize: ${toString parallelize})" pkg.override {
        stdenv = pkgs.addAttrsToDerivation (_optimizeAttrs (attrs // {inherit level parallelize; })) pkgs.fastStdenv;
      }
    else
      warn "Can't optimize ${getName pkg}" pkg
  );
in
{
  options.aviallon.optimizations = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's optimizations";
      type = types.bool;
    };
    lto = mkEnableOption "enable LTO for some packages";
    extraCompileFlags = mkOption {
      default = [ "-mtune=${generalCfg.cpuTune}" ];
      example = [ "-O2" "-mavx" ];
      description = "Add specific compile flags";
      type = types.listOf types.str;
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = mkBefore [
      (self: super: {
        opensshOptimized = optimizePkg { level = "very-unsafe"; lto = true; } super.openssh;
        #libxslt = optimizePkg { level = "unsafe"; parallelize = generalCfg.cores; lto = true; } super.libxslt;
        htop = optimizePkg {parallelize = generalCfg.cores; lto = true; } super.htop;
        nano = optimizePkg {level = "unsafe";} super.nano;
        virtmanager = optimizePkg {} super.virtmanager;
        libsForQt5 = super.libsForQt5.overrideScope' (mself: msuper: {
          kwin = optimizePkg {} msuper.kwin;
          dolphin = optimizePkg {} msuper.dolphin;
        });
        libsForQt514 = super.libsForQt514.overrideScope' (mself: msuper: {
          kwin = optimizePkg {level = "unsafe"; } msuper.kwin;
          dolphin = optimizePkg {} msuper.dolphin;
        });
        #wayland = optimizePkg super.wayland;
      })
    ];
  };
}
