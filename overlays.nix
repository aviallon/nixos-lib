{config, pkgs, options, lib, ...}:
with builtins;
with lib;
let
  cfg = config.aviallon.overlays;
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
              ++ trace "Using the following interpreters: ${toString (interpreters pkgs)}" (interpreters pkgs)
            );

            # symlink shared assets, including icons and desktop entries
            extraInstallCommands = ''
              ln -s "${unwrapped}/share" "$out/"
            '';

            runScript = "${unwrapped}/bin/pycharm-professional";
          });
        };
      })
    ];
    aviallon.programs.allowUnfreeList = [
      "unrar" "ark"
    ];
  }; 
}
