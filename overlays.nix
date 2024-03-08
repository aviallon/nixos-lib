{config, pkgs, options, lib, ...}:
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

        /*power-profiles-daemon = super.power-profiles-daemon.overrideAttrs (old: {
          patches = [
            # ACPI cpufreq support
            (super.fetchpatch {
              url = "https://gitlab.freedesktop.org/hadess/power-profiles-daemon/-/commit/7ccd832b96d2a0ac8911587d3fa9d18e19bd5587.diff";
              sha256 = "sha256-UTfbUN/rHUFJ8eXOL3P8LCkBr+TySbEer9ti2e0kAiU=";
            })
          ];
        });*/


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

      (final: prev: {
        jetbrains = prev.jetbrains // {
          pycharm-professional-fhs = (
          let
            myIsDerivation = x:
              let
                tryX = tryEval x;
              in
                if
                  tryX.success && (isDerivation tryX.value)
                then
                  if !(tryX.value.meta.insecure || tryX.value.meta.broken)
                  then true
                  else trace "Excluding interpreter ${getName x} from pycharm FHS" false
                else
                  false
              ;
            interpreters = pkgs: filter (x: myIsDerivation x) (attrValues pkgs.pythonInterpreters);
            unwrapped = final.jetbrains.pycharm-professional;
          in prev.buildFHSUserEnv rec {
            name = "pycharm-professional";
            targetPkgs = pkgs: (with pkgs;
              [
                glibc
                bashInteractive

                python3Full
              
                jetbrains.pycharm-professional
              ]
              ++ trace "Using the following interpreters: ${toString (pkgNames (interpreters pkgs))}" (interpreters pkgs)
            );

            # symlink shared assets, including icons and desktop entries
            extraInstallCommands = ''
              ln -s "${unwrapped}/share" "$out/"
            '';

            runScript = "${unwrapped}/bin/pycharm-professional";
          });


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
