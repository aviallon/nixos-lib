{config, pkgs, options, lib, ...}:
with lib;
let
  cfg = config.aviallon.overlays;
in
{
  options.aviallon.overlays = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Wether to enable system-wide overlays or not";
      type = types.bool;
    };
    optimizations = mkOption {
      default = true;
      example = false;
      description = "Wether to enable CPU-specific optimizations for some packages or not";
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
        steam = super.steam.override {
          withJava = true;
        };
        ark = super.ark.override {
          unfreeEnableUnrar = true;
        };
        ungoogled-chromium = super.ungoogled-chromium.override {
          enableWideVine = true;
        };
        chromium = super.chromium.override {
          enableWideVine = true;
        };


        power-profiles-daemon = super.power-profiles-daemon.overrideAttrs (old: {
          patches = [
            # ACPI cpufreq support
            (super.fetchpatch {
              url = "https://gitlab.freedesktop.org/hadess/power-profiles-daemon/-/commit/7ccd832b96d2a0ac8911587d3fa9d18e19bd5587.diff";
              sha256 = "sha256-UTfbUN/rHUFJ8eXOL3P8LCkBr+TySbEer9ti2e0kAiU=";
            })
          ];
        });

        myFFmpeg = let
          withUnfree = super.unstable.ffmpeg-full.override { withUnfree = true; };
          withTensorflow = withUnfree.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [ super.libtensorflow ];
            configureFlags = (old.configureFlags or []) ++ [ "--enable-libtensorflow" ];
          });
        in withTensorflow;

        amdctl = super.callPackage ./packages/amdctl.nix {};

        # Use bleeding-edge linux firmware
        linux-firmware = super.unstable.linux-firmware;

        myFirefox = (super.callPackage ./packages/firefox.nix config.aviallon.desktop.browser.firefox.overrides);
      })
      (final: prev: {
        # Use our kernel for generating linux man pages
        linux-manual = prev.linux-manual.override { linuxPackages_latest = config.boot.kernelPackages; };
      })
      (self: super: {
        nextcloud-client = super.nextcloud-client.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ (with super; [
            extra-cmake-modules
          ]);
          buildInputs = old.buildInputs ++ (with super; with libsForQt5; [
            kio
          ]);
        });
      })

      (final: prev: {
        jetbrains = prev.jetbrains // {
          pycharm-professional-fhs = (
          let
            unwrapped = final.jetbrains.pycharm-professional;
          in prev.buildFHSUserEnv rec {
            name = "pycharm-professional";
            targetPkgs = pkgs: (with pkgs; [
              glibc

              python3Full
              python311
              python310Full
              python39Full
              python38Full
              python37Full
            
              jetbrains.pycharm-professional
            ]);

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
      "chromium-unwrapped" "chrome-widevine-cdm"
      "ungoogled-chromium" "chromium" # because of widevine

      "ffmpeg-full" # Because of unfree codecs
    ];
  }; 
}
