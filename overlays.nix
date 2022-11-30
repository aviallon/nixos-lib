{config, pkgs, options, lib, ...}:
with lib;
let
  cfg = config.aviallon.overlays;
  unstable = import (fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    rev = "c573e3eaa8717fbabab3f9a58bfed637fb441eac";
    ref = "nixos-unstable";
  }) {
    config = config.nixpkgs.config // { allowUnfree = true; } ;
    overlays = config.nixpkgs.overlays;
  };
  nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") { inherit pkgs; };
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
      # Prepend default nixPath values.
      options.nix.nixPath.default ++
      # Append our nixpkgs-overlays.
      [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ]
    ;


    nixpkgs.overlays = []
      ++ [(self: super: {
        inherit unstable;
        inherit nur;
      })]
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

        opensshOptimized = super.opensshOptimized or super.openssh;


        xwayland = super.xwayland.overrideAttrs (old: {
          buildInputs = old.buildInputs or [] ++ [ super.makeWrapper ];
          postInstall = old.postInstall or "" + ''
            # Force EGL Stream support
            wrapProgram $out/bin/Xwayland --add-flags "-eglstream"
          '';
        });

        ffmpeg-full = let
          withLto = super.ffmpeg-full.override { enableLto = false; rav1e = self.rav1e; };
          withTensorflow = withLto.overrideAttrs (old: {
            CFLAGS = (old.CFLAGS or "") + " -march=${config.aviallon.general.cpuArch}";
            LDFLAGS = (old.LDFLAGS or "") + " -march=${config.aviallon.general.cpuArch}";
            buildInputs = (old.buildInputs or []) ++ [ super.libtensorflow-bin ];
            configureFlags = (old.configureFlags or []) ++ [ "--enable-libtensorflow" ];
          });
        in withTensorflow;


        myFirefox = (import ./packages/firefox.nix { pkgs = self; inherit lib; });
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

    ];

    aviallon.programs.allowUnfreeList = [
      "unrar" "ark"
      "chromium-unwrapped" "chrome-widevine-cdm"
      "ungoogled-chromium" "chromium" # because of widevine
    ];
  }; 
}
