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
    nixpkgs.overlays = mkAfter [
      (self: super: {
        jetbrains = super.jetbrains // {
          jdk = optimizePkg {} super.jetbrains.jdk;
        };
      })
    ];
  };
}
