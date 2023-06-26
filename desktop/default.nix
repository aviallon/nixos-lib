{ config, pkgs, lib, ... }:
with lib;
{
  imports = [
    ./general.nix
    ./developer.nix
    ./multimedia.nix
    ./plasma.nix
    ./games.nix
    ./browser.nix
    ./gnome.nix
    ./printing.nix
  ];
}
