{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  _trace = if cfg.trace then (traceValSeqN 2) else (x: x);

  _optimizeAttrs = 
    {
      lto ? false , 
      go ? false , 
      cmake ? false , 
      cpuArch ? generalCfg.cpuArch , 
      cpuTune ? generalCfg.cpuTune ,
      extraCFlags ? cfg.extraCompileFlags ,
      ...
    }@attrs:
      _trace (
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

  addAttrs = pkg: attrs: pkg.overrideAttrs (old: _trace (myLib.attrsets.mergeAttrsRecursive old attrs) );

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

  
  optimizePkg = {level ? "normal" , recursive ? 0 , _depth ? 0 , ... }@attrs: pkg:
    if (hasAttr "overrideAttrs" pkg) then
      let
        optimizedAttrs = _optimizeAttrs (attrs // {inherit level; go = (hasAttr "GOARCH" pkg); });
        _buildInputs = filter (p: ! isNull p ) (pkg.buildInputs or []);
        _buildInputsOverriden = forEach _buildInputs (_pkg:
          if (any (n: n == getName _pkg) cfg.blacklist) then
            warn "Skipping blacklisted '${getName _pkg}'" _pkg
          else optimizePkg ({}
                // attrs
                // {
                  inherit level recursive;
                  parallelize = null;
                  _depth = _depth + 1;
                }) _pkg
        );
        _pkg =
          if (recursive > _depth) then
            pkg.overrideAttrs (old: {}
              // {
                buildInputs = _buildInputsOverriden;
              }
              // optionalAttrs (hasAttr "CFLAGS" old) {
                CFLAGS = if (! isList old.CFLAGS ) then [ old.CFLAGS ] else old.CFLAGS;
              }
            )
          else pkg;
      in trace "Optimized ${getName pkg} with overrideAttrs at level '${level}' (depth: ${toString _depth})" (addAttrs _pkg optimizedAttrs)
    else
      warn "Can't optimize ${getName pkg} (depth: ${toString _depth})" pkg
  ;
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
    trace = mkEnableOption "trace attributes in overriden derivations";
    blacklist = mkOption {
      default = [ # Broken
                  "cmocka" "libkrb5" "libidn2" "tpm2-tss" "libxcrypt"
                  "libomxil-bellagio" "wayland" "wayland-protocols"
                  "openssl" "libXt"

                  # Very slow
                  "llvm" "clang" "clang-wrapper" "valgrind" "rustc"
                ];
      example = [ "bash" ];
      description = "Blacklist specific packages from optimizations";
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
        opensshOptimized = optimizePkg { level = "very-unsafe"; recursive = 0; lto = true; } super.openssh;
        htop = optimizePkg {
            level = "unsafe";
            lto = true;
          } super.htop;
        nano = optimizePkg {level = "unsafe"; recursive = 99; } super.nano;
      })
    ];
  };
}
