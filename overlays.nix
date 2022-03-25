{config, pkgs, options, lib, ...}:
with lib;
let
  cfg = config.aviallon.overlays;
  unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { config = config.nixpkgs.config; };
  optimizeWithFlag = pkg: flag:
    pkg.overrideAttrs (attrs: {
      NIX_CFLAGS_COMPILE = (attrs.NIX_CFLAGS_COMPILE or "") + " ${flag}";
      doCheck = false;
    });
  optimizeWithFlags = pkg: flags: pkgs.lib.foldl' (pkg: flag: optimizeWithFlag pkg flag) pkg flags;
  optimizeForThisHost = pkg: optimizeWithFlags pkg (builtins.trace "${getName pkg}: ${toString config.aviallon.programs.compileFlags}" config.aviallon.programs.compileFlags);
in
{
  options.aviallon.overlays = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Wether to enable system-wide overlays or not";
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
      })
      (self: super: {
        opensshOptimized = optimizeForThisHost super.openssh;
        rsyncOptimized = optimizeForThisHost super.rsync;
        nano = optimizeForThisHost super.nano;
        veracrypt = optimizeForThisHost pkgs.veracrypt;
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
        steam = super.steam.override {
          withJava = true;
        };
        ark = optimizeForThisHost (super.ark.override {
          unfreeEnableUnrar = true;
        });
      })
    #  (self: super: {
    #    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
    #      inherit pkgs;
    #    };
    #  })
    ];

    aviallon.programs.allowUnfreeList = [ "unrar" "ark" ];
  }; 
}
