{ config, pkgs, lib, ... }:
with lib;
{
  imports = [
    ./developer.nix
    ./multimedia.nix
    ./plasma.nix
    ./games.nix
  ];
}
