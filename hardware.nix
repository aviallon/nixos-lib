{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.hardware = {
    gpuVendor = mkOption {
      default = null;
      example = "amd";
      description = "Enable GPU vendor specific options";
      type = types.enum [ "amd" "nvidia" "intel" ];
    };
  };

  imports = [
    ./hardware/amd.nix
    ./hardware/nvidia.nix
    ./hardware/intel.nix
  ];

}
