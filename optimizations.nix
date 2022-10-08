{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  _optimizeAttrs = 
    {
      lto ? false , 
      go ? false , 
      cmake ? true , 
      cpuArch ? generalCfg.cpuArch , 
      cpuTune ? generalCfg.cpuTune ,
      extraCFlags ? cfg.extraCompileFlags ,
      ...
    }@attrs:
      traceValSeq (
        (myLib.optimizations.makeOptimizationFlags ({
          inherit lto go cpuArch cpuTune extraCFlags;
        } // attrs))
        // (optionalAttrs cmake {
          preConfigure = ''
            cmakeFlagsArray+=(
              "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
              "-DCMAKE_C_FLAGS=$CFLAGS"
            )
          '';
        })
        // (optionalAttrs go {
          nativeBuildInputs = [ pkgs.gccgo ];
        }
      )
  );

  addAttrs = pkg: attrs: pkg.overrideAttrs (old: traceValSeqN 2 (myLib.attrsets.mergeAttrsRecursive old attrs) );
  
  optimizePkg = {level ? "normal", useAttrs ? false , ... }@attrs: pkg:
  let
    optimizedAttrs = _optimizeAttrs (attrs // {inherit level; go = (hasAttr "GOARCH" pkg); });
    optStdenv = pkgs.addAttrsToDerivation optimizedAttrs pkgs.fastStdenv;
  in (
    if (!useAttrs) && (hasAttr "stdenv" pkg.override.__functionArgs) then
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
            optimizedAttrs = {}
              #// _optimizeAttrs { level = "general"; cpuArch = null; cpuTune = null; }
              // {
                configureFlags = [
                  "--with-cpu-64=${generalCfg.cpuArch}" "--with-arch-64=${generalCfg.cpuArch}"
                  "--with-tune-64=${generalCfg.cpuTune}"
                  "--with-build-config=bootstrap-lto-lean"
                ];
              }
            ;
            ccWithProfiling = old.cc.overrideAttrs (_: { buildFlags = [ "profiledbootstrap" ]; } );
          in {
            cc = addAttrs ccWithProfiling optimizedAttrs;
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
          plasma5 = msuper.plasma5.overrideScope' (mself: msuper: {
            kwin = optimizePkg {level = "unsafe"; lto = true; } msuper.kwin;
          });
        });
        #wayland = optimizePkg super.wayland;
      })
    ];
  };
}
