{ config, nixpkgs-unstable, lib, pkgs, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
in {
  disabledModules = [
    "services/x11/display-managers/sddm.nix"
    "services/x11/display-managers/default.nix"
    "services/x11/window-managers/default.nix"
  ];

  imports = [
    (import (nixpkgs-unstable + /nixos/modules/services/display-managers/sddm.nix))
    (import (nixpkgs-unstable + /nixos/modules/services/display-managers/default.nix))
    (import (nixpkgs-unstable + /nixos/modules/services/x11/window-managers/default.nix))
    (mkRenamedOptionModule [ "services" "xserver" "displayManager" "session" ] [ "services" "displayManager" "session" ])
  ];

  config = {
    services.displayManager.sddm.wayland.compositor = "kwin";
  
    nixpkgs.overlays = [
      (final: prev: {
        sddm = final.libsForQt5.sddm;
        libsForQt5 = prev.libsForQt5.overrideScope (f: p: {
          sddm = f.callPackage (import (nixpkgs-unstable + /pkgs/applications/display-managers/sddm)) {};
        });
        kdePackages = final.libsForQt5;
      })
    ];
  };
}
