{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.hardware = {  };

  imports = [
    ./hardware/amd.nix
    ./hardware/nvidia.nix
    ./hardware/intel.nix
  ];

}
