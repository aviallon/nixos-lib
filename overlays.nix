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
  };
  config = mkIf cfg.enable {
     nix.nixPath =
      # Prepend default nixPath values.
      options.nix.nixPath.default ++
      # Append our nixpkgs-overlays.
      [ "nixpkgs-overlays=/etc/nixos/overlays-compat/" ]
    ;


    nixpkgs.overlays = [
      (self: super: {
          inherit unstable;
          inherit nur;
      })
      (self: super: {
        htop = super.htop.overrideAttrs (old: {
          configureFlags = old.configureFlags ++ [
            "--enable-hwloc"
          ];
        
          nativeBuildInputs = old.nativeBuildInputs ++ (with super; [
            pkg-config
          ]);
          buildInputs = old.buildInputs ++ (with super; [
            libunwind
            libcap
            libnl
            hwloc
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

        scribus = super.scribus.overrideAttrs (old: rec {
          version = "1.5.8";
          sha256 = "sha256-R4Fuj89tBXiP8WqkSZ+X/yJDHHd6d4kUmwqItFHha3Q=";
          src = super.fetchurl {
            url = "mirror://sourceforge/${old.pname}/${old.pname}-devel/${old.pname}-${version}.tar.xz";
            inherit sha256;
          };
          patches = with super; [
            # For Poppler 22.02
            (fetchpatch {
              url = "https://github.com/scribusproject/scribus/commit/85c0dff3422fa3c26fbc2e8d8561f597ec24bd92.patch";
              sha256 = "YR0ii09EVU8Qazz6b8KAIWsUMTwPIwO8JuQPymAWKdw=";
            })
            (fetchpatch {
              url = "https://github.com/scribusproject/scribus/commit/f19410ac3b27e33dd62105746784e61e85b90a1d.patch";
              sha256 = "JHdgntYcioYatPeqpmym3c9dORahj0CinGOzbGtA4ds=";
            })
            (fetchpatch {
              url = "https://github.com/scribusproject/scribus/commit/e013e8126d2100e8e56dea5b836ad43275429389.patch";
              sha256 = "+siPNtJq9Is9V2PgADeQJB+b4lkl5g8uk6zKBu10Jqw=";
            })
            (fetchpatch {
              url = "https://github.com/scribusproject/scribus/commit/48263954a7dee0be815b00f417ae365ab26cdd85.patch";
              sha256 = "1WE9kALFw79bQH88NUafXaZ1Y/vJEKTIWxlk5c+opsQ=";
            })
            (fetchpatch {
              url = "https://github.com/scribusproject/scribus/commit/f2237b8f0b5cf7690e864a22ef7a63a6d769fa36.patch";
              sha256 = "FXpLoX/a2Jy3GcfzrUUyVUfEAp5wAy2UfzfVA5lhwJw=";
            })
          ];
        });
        # chromium = self.ungoogled-chromium;

        gccgo11 = super.wrapCC (super.gcc11.cc.override {
          name = "gccgo11";
          langCC = true;
          langC = true;
          langGo = true;
          profiledCompiler = false;
        });
        gccgo = self.gccgo11;

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
