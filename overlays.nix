{config, pkgs, options, lib, myLib, ...}:
with builtins;
with lib;
let
  cfg = config.aviallon.overlays;
  pkgNames = pkgs: forEach pkgs (p: "${getName p}-${p.version}");
in
{

  imports = [
    (mkRenamedOptionModule [ "aviallon" "overlays" "optimizations" ] [ "aviallon" "optimizations" "enable" ])
  ];

  options.aviallon.overlays = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Wether to enable system-wide overlays or not";
      type = types.bool;
    };
    traceCallPackage = mkEnableOption "printing package names each time callPackage is evaluated";
  };
  config = mkIf cfg.enable {
     nix.nixPath =
      # Append our nixpkgs-overlays.
      [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ]
    ;


    nixpkgs.overlays = []
      ++ optional cfg.traceCallPackage (self: super: {
        callPackage = path: overrides:
          let
             _pkg = super.callPackage path overrides;
             _name = _pkg.name or _pkg.pname or "<unknown>";
          in trace "callPackage ${_name}" _pkg
        ;
      })
      ++ [(self: super: {
        htop = super.htop.overrideAttrs (old: {
          configureFlags = old.configureFlags ++ [
            "--enable-affinity"
            "--enable-delayacct"
            "--enable-capabilities"
          ];
        
          nativeBuildInputs = old.nativeBuildInputs ++ (with super; [
            pkg-config
          ]);
          buildInputs = old.buildInputs ++ (with super; [
            libcap
            libunwind
            libnl
          ]);
        });
        ark = super.ark.override {
          unfreeEnableUnrar = true;
        };

      })
      (final: prev: {
        # Use our kernel for generating linux man pages
        linux-manual = prev.linux-manual.override { linuxPackages_latest = config.boot.kernelPackages; };
      })

      (final: prev: {
        lutris-fhs =
          (prev.buildFHSUserEnv {
            name = "lutris";
            targetPkgs = pkgs: (with pkgs;
              [
                glibc
                bashInteractive

                python3Full

                lutris
                gamescope
                wineWowPackages.waylandFull
                flatpak
              ]
            );

            # symlink shared assets, including icons and desktop entries
            extraInstallCommands = ''
              ln -s "${pkgs.lutris}/share" "$out/"
            '';

            runScript = "/usr/bin/lutris";
          });
      })

      (final: prev: let
        pycharm-common = pkg:
          let
            myIsDerivation = x: !(myLib.derivations.isBroken x);
            interpreters = pkgs: filter (x: myIsDerivation x) (attrValues pkgs.pythonInterpreters);
          in prev.buildFHSUserEnv rec {
            name = pkg.pname;
            targetPkgs = pkgs: (with pkgs;
              [
                glibc
                bashInteractive
                zlib

                python3Full
              
                pkg
              ]
              ++ trace "Using the following interpreters: ${toString (pkgNames (interpreters pkgs))}" (interpreters pkgs)
            );

            # symlink shared assets, including icons and desktop entries
            extraInstallCommands = ''
              ln -s "${pkg}/share" "$out/"
            '';

            runScript = "/usr/bin/${pkg.pname}";
          };
        in {
        jetbrains = prev.jetbrains // {
          pycharm-community-fhs = pycharm-common prev.jetbrains.pycharm-community;
          pycharm-professional-fhs = pycharm-common prev.jetbrains.pycharm-professional;

          clion-fhs = let
            compilers = pkgs: with pkgs; with llvmPackages_17; [
              (setPrio (-9) gcc13)
              (hiPrio clang)
              clang-unwrapped
              libcxx
            ];
          in prev.buildFHSUserEnv rec {
            name = "clion";
            targetPkgs = pkgs: (with pkgs;
              [
                jetbrains.clion
                (hiPrio cmake)
                (hiPrio ninja)
                gnumake
                extra-cmake-modules
              ]
              ++ trace "Using the following compilers: ${toString (pkgNames (compilers pkgs))}" (compilers pkgs)
            );
            # symlink shared assets, including icons and desktop entries
            extraInstallCommands = ''
              ln -s "${prev.jetbrains.clion}/share" "$out/"
            '';
            extraOutputsToInstall = [ "include" "dev" "doc" ];

            runScript = "/usr/bin/clion";
          };
        };
      })

    ];
    aviallon.programs.allowUnfreeList = [
      "unrar" "ark"
    ];
  }; 
}
