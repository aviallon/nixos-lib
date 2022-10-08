{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  _optimizeAttrs = { lto ? false , go ? false, ... }@attrs:
    traceValSeq (
    (myLib.optimizations.makeOptimizationFlags ({
      inherit lto go;
      cpuArch = generalCfg.cpuArch;
      cpuTune = generalCfg.cpuTune;
      extraCFlags = cfg.extraCompileFlags;
    } // attrs))
    // {
      preConfigure = ''
        cmakeFlagsArray+=(
          "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
          "-DCMAKE_C_FLAGS=$CFLAGS"
        )
      '';
    }
    // (optionalAttrs go {
      buildInputs = [ pkgs.gccgo ];
    })
  );

  addAttrs = pkg: attrs: pkg.overrideAttrs (old: traceValSeqN 2 (myLib.attrsets.mergeAttrsRecursive old attrs) );
  
  optimizePkg = {level ? "normal", ... }@attrs: pkg:
  let
    optimizedAttrs = _optimizeAttrs (attrs // {inherit level; go = (hasAttr "GOARCH" pkg); });
    optStdenv = pkgs.addAttrsToDerivation optimizedAttrs pkgs.fastStdenv;
  in (
    if (hasAttr "stdenv" pkg.override.__functionArgs) then
      trace "Optimized ${getName pkg} with stdenv at level '${level}'" pkg.override {
        stdenv = optStdenv;
      }
    else if (hasAttr "overrideAttrs" pkg) then
      trace "Optimized ${getName pkg} with overrideAttrs at level '${level}'" (addAttrs pkg optimizedAttrs)
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
        fastStdenv = super.overrideCC super.gccStdenv (super.buildPackages.gcc_latest.overrideAttrs (old:
          let
            ccAttrs = cc: cc.overrideAttrs (oldAttrs: {
              configureFlags = (oldAttrs.configureFlags or []) ++ [ "--with-cpu-64=${generalCfg.cpuArch}" "--with-arch-64=${generalCfg.cpuTune}" ];
            });
            ccOverrides = cc: cc.override {
              reproducibleBuild = false;
            };
          in {
            cc = ccOverrides (ccAttrs old.cc);
          }
        ));
      })
    
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
