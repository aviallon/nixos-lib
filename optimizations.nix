{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  _optimizeAttrs = level:
    traceValSeq ((myLib.optimizations.makeOptimizationFlags {
      inherit level;
      cpuArch = generalCfg.cpuArch;
      extraCFlags = cfg.extraCompileFlags;
    }) // {
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
  
  optimizePkg = {level ? "normal" }: pkg:
  (
    if (hasAttr "stdenv" pkg.override.__functionArgs) then
      trace "Optimized ${getName pkg} with stdenv" pkg.override {
        stdenv = pkgs.addAttrsToDerivation (_optimizeAttrs level) pkgs.fastStdenv;
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
        htop = optimizePkg {} super.htop;
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
