{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
in
{
  options.aviallon.hardware = {  };

  imports = [
    ./amd
    ./nvidia
    ./intel
    ./mesa.nix
  ];

  config = {};

}
