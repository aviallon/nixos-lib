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

#   imports = [
#     (if (cfg.gpuVendor == "amd") then ./hardware/amd.nix else "")
#     (if (cfg.gpuVendor == "nvidia") then ./hardware/nvidia.nix else "")
#     (if (cfg.gpuVendor == "intel") then ./hardware/intel.nix else "")
#   ];
}
