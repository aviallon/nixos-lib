{ config, pkgs, lib, ... }:
with lib;
{
  imports = [
    ./general.nix
    ./developer.nix
    ./multimedia.nix
    ./plasma
    ./games.nix
    ./browser.nix
    ./gnome.nix
    ./printing.nix
    ./flatpak.nix
    ./sddm.nix
  ];
}
