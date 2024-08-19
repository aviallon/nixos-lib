{ config, pkgs, options, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  addAttrs = myLib.optimizations.addAttrs;

  defaultOptimizeAttrs = {
    level = "normal";
    recursive = 0;
    cpuCores = generalCfg.cpu.threads;
    cpuArch = generalCfg.cpu.arch;
    cpuTune = generalCfg.cpu.tune;
    l1dCache = generalCfg.cpu.caches.l1d;
    l1iCache = generalCfg.cpu.caches.l1i;
    l1LineCache = generalCfg.cpu.caches.cacheLine;
    lastLevelCache = generalCfg.cpu.caches.lastLevel;
    extraCFlags = cfg.extraCompileFlags;
    blacklist = cfg.blacklist;
    ltoBlacklist = cfg.lto.blacklist;
    overrideMap = cfg.overrideMap;
    lto = cfg.lto.enable;
  };

  optimizePkg = {
      attributes ? {},
      stdenv ? null,
      ...
    }@attrs: pkg:
      myLib.optimizations.optimizePkg pkg (
        defaultOptimizeAttrs
        // cfg.defaultSettings
        // { inherit stdenv attributes; }
        // attrs
      );
in {
  options.aviallon.optimizations = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's optimizations";
      type = types.bool;
    };
    lto = {
      enable = mkOption {
        description = "Wether to enable LTO for some packages";
        type = types.bool;
        default = true;
      };
      blacklist = mkOption {
        description = "Packages to blacklist from LTO";
        type = types.listOf types.str;
        default = [ "x265" "cpio" "cups" "gtk+3" "which" "openssh" ];
      };
    };
    extraCompileFlags = mkOption {
      default = [ ];
      example = [ "-O2" "-mavx" ];
      description = "Add specific compile flags";
      type = types.listOf types.str;
    };
    defaultSettings = mkOption {
      default = {
        recursive = 0;
        level = "slower";
      };
      example = { level = "unsafe"; recursive = 0; };
      description = mdDoc "Specify default options passed to optimizePkg";
    };
    optimizePkg = mkOption {
      default = if cfg.enable then optimizePkg else ({...}: pkg: pkg);
      example = "pkg: pkg.override { stdenv = pkgs.fastStdenv; }";
      description = "Function used for optimizing packages";
      type = with types; functionTo (functionTo package);
    };
    trace = mkEnableOption "trace attributes in overriden derivations";
    runtimeOverrides.enable = mkEnableOption "runtime overrides for performance sensitive libraries (glibc, ...)";
    blacklist = mkOption {
      default = [ # Broken
                  "alsa-lib" "glib" "lcms2" "gconf" "gnome-vfs"

                  # Very slow
                  "llvm" "clang" "clang-wrapper" "valgrind" "rustc" "tensorflow" "qtwebengine"

                  # Fixable with work, but slow for now
                  "rapidjson"
                ];
      example = [ "bash" ];
      description = "Blacklist specific packages from optimizations";
      type = types.listOf types.str;
    };
    overrideMap = mkOption {
      type = with types; attrsOf package;
      default = {
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

    aviallon.optimizations.blacklist = mkDefault (
        options.aviallon.optimizations.blacklist.default
        ++ (traceValSeq (forEach config.system.replaceRuntimeDependencies (x: lib.getName x.oldDependency )))
    );
    system.replaceRuntimeDependencies = mkIf (!lib.inPureEvalMode && cfg.runtimeOverrides.enable) [
      # glibc usually represents 20% of the userland CPU time. It is therefore very much worth optimizing.
      /*{
        original = pkgs.glibc;
        replacement = let
          optimizedFlags = [ "-fipa-pta" ];
          #optimizedFlags = myLib.optimizations.guessOptimizationsFlags pkgs.glibc (defaultOptimizeAttrs // { level = "slower"; recursive = 0; });
        in pkgs.glibc.overrideAttrs (attrs: myLib.debug.traceValWithPrefix "optimizations (glibc)" {
          passthru = pkgs.glibc.passthru;
          env = (attrs.env or {}) // {
            NIX_CFLAGS_COMPILE = (attrs.env.NIX_CFLAGS_COMPILE or "") + (toString optimizedFlags.CFLAGS);
          };
        });
      }*/
      # zlib is in second place, given how often it is used
      #{
      #  original = pkgs.zlib;
      #  replacement = optimizePkg { level = "slower"; } pkgs.zlib;
      #}
    ];

    nixpkgs.overlays = mkAfter [
      (self: super: {
        fastStdenv = super.overrideCC super.gccStdenv (super.buildPackages.gcc_latest.overrideAttrs (old:
          let
            optimizedAttrs = {}
              // {
                configureFlags = [
                  "--with-cpu-64=${generalCfg.cpu.arch}" "--with-arch-64=${generalCfg.cpu.arch}"
                  "--with-tune-64=${generalCfg.cpu.tune}"
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
        #jetbrains = super.jetbrains // {
        #  jdk = pipe super.jetbrains.jdk [
        #    (optimizePkg { level = "normal"; lto = false; })
        #    (pkg: pkg.overrideAttrs (old: {
        #      passthru = pkg.passthru or {};
        #      #configureFlags = (old.configureFlags or []) ++ [ "--with-extra-cflags" "--with-extra-cxxflags" "--with-extra-ldflags" ];
        #    }))
        #  ];
        #};
      })
    ];
  };
}
