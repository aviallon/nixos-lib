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
  optimizeWithFlags = pkg: flags:
    pkg.overrideAttrs (attrs: {
      NIX_CFLAGS_COMPILE = toString ([ (attrs.NIX_CFLAGS_COMPILE or "") ] ++ flags);
      doCheck = false;
    });
  _optimizeForThisHost = pkg:
     pkg.overrideAttrs (attrs: let
      cflags = [ (attrs.NIX_CFLAGS_COMPILE or "") ] ++ config.aviallon.programs.compileFlags;
      cxxflags = [ (attrs.CXXFLAGS or "") ] ++ config.aviallon.programs.compileFlags;
      rustflags = [ (attrs.RUSTFLAGS or "") "-C target-cpu=${config.aviallon.general.cpuArch}" ];
      pkgname = getName pkg;
      cmakeflags = mytrace "cmakeflags" "-DCMAKE_CXX_FLAGS=${toString cxxflags}";
      configureflags = [ (attrs.configureFlags or "") ] ++ [
        "--enable-lto" "--enable-offload-targets=nvptx-none" "--disable-libunwind-exceptions"
      ];
      mytrace = name: value: builtins.trace "${pkgname}: ${name}: ${toString value}" (toString value);
     in {
      stdenv = pkgs.fastStdenv;
      NIX_CFLAGS_COMPILE = mytrace "CFLAGS" cflags;
      CXXFLAGS = mytrace "CXXFLAGS" cxxflags;
      RUSTFLAGS = mytrace "RUSTFLAGS" rustflags;
      configureFlags = mytrace "configureFlags" configureflags;
      preConfigure = ''
        cmakeFlagsArray+=(
          "${cmakeflags}"
        )
      '';
      doCheck = false;
    });
   optimizeForThisHost = if (cfg.optimizations) then (pkg: _optimizeForThisHost pkg) else (pkg: pkg);
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
        nextcloud-client = optimizeForThisHost (super.nextcloud-client.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ (with super; [
            extra-cmake-modules
          ]);
          buildInputs = old.buildInputs ++ (with super; with libsForQt5; [
            kio
          ]);
        }));
      })
      # KDE packages
      (self: super: {
        libsForQt5 = super.libsForQt5.overrideScope' (mself: msuper: {
          kwin = optimizeForThisHost msuper.kwin;
          dolphin = optimizeForThisHost msuper.dolphin;
        });
      })
      (self: super: {
        opensshOptimized = optimizeForThisHost super.openssh;
        rsyncOptimized = optimizeForThisHost super.rsync;
        nano = optimizeForThisHost super.nano;
        veracrypt = optimizeForThisHost super.veracrypt;
        htop = optimizeForThisHost (super.htop.overrideAttrs (old: {
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
        }));
        # mesa = optimizeForThisHost super.mesa;
        #xorg = super.xorg.overrideScope' (mself: msuper: {
        #  xorgserver = optimizeForThisHost msuper.xorgserver;
        #});
        steam = super.steam.override {
          withJava = true;
        };
        ark = optimizeForThisHost (super.ark.override {
          unfreeEnableUnrar = true;
        });
        ungoogled-chromium = super.ungoogled-chromium.override {
          enableWideVine = true;
        };
        chromium = super.chromium.override {
          enableWideVine = true;
        };
        # chromium = self.ungoogled-chromium;

        myFirefox = (import ./packages/firefox.nix { pkgs = self; inherit lib; });

        kvdo = config.boot.kernelPackages.callPackage ./packages/kvdo.nix { };
      })
    ];

    aviallon.programs.allowUnfreeList = [
      "unrar" "ark"
      "chromium-unwrapped" "chrome-widevine-cdm"
      "ungoogled-chromium" "chromium" # because of widevine
    ];
  }; 
}
