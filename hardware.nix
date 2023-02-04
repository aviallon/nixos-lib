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

    environment.systemPackages = []
      ++ optional (cfg.amd.enable && cfg.nvidia.enable) pkgs.nvtop
      ++ optional cfg.amd.enable pkgs.nvtop-amd
      ++ optional cfg.nvidia.enable pkgs.nvtop-nvidia
    ;

  };

}
