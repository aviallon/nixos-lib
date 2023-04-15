{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  addAttrs = myLib.optimizations.addAttrs;

  optimizePkg = {
      cpuCores ? generalCfg.cores,
      cpuArch ? generalCfg.cpuArch,
      cpuTune ? generalCfg.cpuTune,
      extraCFlags ? cfg.extraCompileFlags,
      blacklist ? cfg.blacklist,
      overrideMap ? cfg.overrideMap,
      ...


  recurseOverrideCflags = pkg: { cflags ? compilerFlags, _depth ? 0 }:
    let
      deps = pkg.buildInputs or [];
      depsOverriden = forEach deps (_pkg: recurseOverrideCflags _pkg {
        inherit cflags;
        _depth = _depth + 1;
      });
    in if isNull pkg then
      warn "pkg is null" pkg
    else if (hasAttr "overrideAttrs" pkg) then
      info "Optimizing '${getName pkg}' at depth ${toString _depth}"
      (pkg.overrideAttrs (old:
        let
          _cflags = 
            if (! hasAttr "CFLAGS" old) then
              []
            else if isList old.CFLAGS then 
              old.CFLAGS
            else
              [ old.CFLAGS ]
            ;
        in {
          buildInputs = depsOverriden;
          CFLAGS = _cflags ++ cflags;
        }
      ))
    else
      warn "Couldn't optimize '${getName pkg}'" pkg
  ;

    }@attrs: pkg:
      myLib.optimizations.optimizePkg pkg ({
        inherit cpuCores cpuTune cpuArch extraCFlags blacklist overrideMap;
      } // attrs);
in {
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
    trace = mkEnableOption "trace attributes in overriden derivations";
    blacklist = mkOption {
      default = [ # Broken
                  "cmocka" "libkrb5" "libidn2" "tpm2-tss" "libxcrypt"
                  "libomxil-bellagio" "wayland" "wayland-protocols"
                  "openssl" "libXt" "intel-media-sdk"
                  "zlib"

                  # Very slow
                  "llvm" "clang" "clang-wrapper" "valgrind" "rustc" "tensorflow"
                ];
      example = [ "bash" ];
      description = "Blacklist specific packages from optimizations";
      type = types.listOf types.str;
    };
    overrideMap = mkOption {
      type = with types; attrsOf package;
      default = {
        stdenv = pkgs.fastStdenv;
      };
      example = literalExpression
        ''
          {
            ninja = pkgs.ninja-samurai;
            cmake = pkgs.my-cmake-override;
          }
        '';
      description = mdDoc "Allow overriding packages found in `nativeBuildInputs` with custom packages.";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = mkAfter [
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
        opensshOptimized = optimizePkg {
            level = "very-unsafe";
            recursive = 0;
            lto = true;
          } super.openssh;
        htop = optimizePkg {
            level = "slower";
            lto = true;
          } super.htop;
        nano = optimizePkg {
            level = "slower";
            recursive = 99;
            lto = true;
          } super.nano;
        mesaOptimized = optimizePkg {
            level = "slower";
            recursive = 1;
            lto = true;
            extraCFlags = cfg.extraCompileFlags;
          } super.mesa;
        optipngOptimized = optimizePkg {
            level = "unsafe";
            lto = true;
            recursive = 1;
            parallelize = generalCfg.cores;
          } super.optipng;
        myFFmpeg = optimizePkg {
            level = "normal";
            lto = false;
            recursive = 1;
          } super.myFFmpeg;
      })
    ];
  };
}
