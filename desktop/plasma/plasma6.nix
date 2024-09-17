{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generic = import ./generic.nix {
    kdePackages = pkgs.kdePackages;
  };
in {
  config = mkIf (cfg.enable && (cfg.environment == "plasma6")) {
    # Enable the Plasma 6 Desktop Environment.
    services.desktopManager.plasma6 = {
      enable = true;
    };

    environment.systemPackages = generic.commonPackages;

    # We prefer Plasma Wayland
    services.displayManager.defaultSession = "plasma";

    # Backport explicit sync patches
    nixpkgs.overlays = [(final: prev: {
      kdePackages = prev.kdePackages // {
        kwin = prev.kdePackages.kwin.overrideAttrs (old: {
          patches = old.patches ++ [
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/c99b3d52f254f3ec60fa27b3100aee79bb57a5f2.diff";
              hash = "sha256-2C5droOWbJjymz00ZfCYTT60qpXmfyvwGURZROTfzjQ=";
            })
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/4aac3914b8744b41d7aa8d9440f19dca4ba3480c.diff";
              hash = "sha256-qAgsiRGikIAu5+hZ/np4bAywORRx16zl5pJcZL/n3Jg=";
            })
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/c56576a62a167930bf1ce7e0130b1ded17fb4efb.diff";
              hash = "sha256-f9+1NUgsC18QUQZVRefDVnnKnMxJthBtj/SHQtZotgc=";
            })
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/272e856780c7386ff1aa3e063975ab1624954a7d.diff";
              hash = "sha256-kgzwhJ1qV78J6DbszVBS2uQfpy/1BVrdZ7IuRz3R4ps=";
            })
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/a5bcbf1c37e8e3a15c26b9b634204f2846b45dde.diff";
              hash = "sha256-Urx3NlaAwUoGds2UWQCeVtJxdIWJsfnSnIsZcXGA8MQ=";
            })
            (prev.fetchpatch {
              url = "https://invent.kde.org/plasma/kwin/-/commit/b162003695f34d64fff929056245c2046cf42e65.diff";
              hash = "sha256-prHXvmI8ByytOHgl90/BQe4Uuo3RYy+ByLlmGUXjf28=";
            })
          ];
        });
      };
    })];
    
  };
}
