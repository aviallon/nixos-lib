{ config, pkgs, options, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  addAttrs = myLib.optimizations.addAttrs;

  optimizePkg = {
      cpuCores ? generalCfg.cpu.threads,
      cpuArch ? generalCfg.cpu.arch,
      cpuTune ? generalCfg.cpu.tune,
      extraCFlags ? cfg.extraCompileFlags,
      blacklist ? cfg.blacklist,
      ltoBlacklist ? cfg.lto.blacklist,
      overrideMap ? cfg.overrideMap,
      lto ? cfg.lto,
      stdenv ? null,
      ...
    }@attrs: pkg:
      myLib.optimizations.optimizePkg pkg (cfg.defaultSettings // {
        inherit cpuCores cpuTune cpuArch extraCFlags blacklist ltoBlacklist overrideMap stdenv;
      } // attrs);
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
        default = [ "x265" "cpio" "cups" "gtk+3" "which" ];
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
        recursive = 1;
        level = "slower";
      };
      example = { level = "unsafe"; recursive = 0; };
      description = mdDoc "Specify default options passed to optimizePkg";
    };
    optimizePkg = mkOption {
      default = optimizePkg;
      example = "pkg: pkg.override { stdenv = pkgs.fastStdenv; }";
      description = "Function used for optimizing packages";
      type = with types; functionTo (functionTo package);
    };
    trace = mkEnableOption "trace attributes in overriden derivations";
    blacklist = mkOption {
      default = [ # Broken
                  "cmocka" "libkrb5" "libidn2" "tpm2-tss" "libxcrypt"
                  "libomxil-bellagio" "wayland" "wayland-protocols"
                  "openssl" "libXt" "intel-media-sdk"
                  "zlib" "alsa-lib" "glib" "lcms2" "gconf" "gnome-vfs"

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
        opensshOptimized = optimizePkg {
            recursive = 0;
          } super.openssh;
        htop = optimizePkg {
          } super.htop;
        nano = optimizePkg {
            recursive = 99;
          } super.nano;
        optipngOptimized = optimizePkg {
            parallelize = generalCfg.cpu.threads;
          } super.optipng;
        myFFmpeg = optimizePkg {
            lto = false;
          } super.myFFmpeg;

        jetbrains = super.jetbrains // {
          jdk = optimizePkg {
              lto = true;
              recursive = 1;
            } super.jetbrains.jdk;
        };

      })
    ];
  };
}
