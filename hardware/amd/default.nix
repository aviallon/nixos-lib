{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  generalCfg = config.aviallon.general;
in {
  options.aviallon.hardware.amd = {
    enable = mkEnableOption "AMD gpus";
    useProprietary = mkEnableOption "Use proprietary AMDGPU Pro";
    defaultVulkanImplementation = mkOption {
      description = "Wether to use RADV or AMDVLK by default";
      type = with types; enum [ "amdvlk" "radv" ];
      default = "radv";
    };
    kernelDriver = mkOption {
      description = "wether to use radeon or amdgpu kernel driver";
      type = with types; enum [ "radeon" "amdgpu" ];
      default = "amdgpu";
    };
  };

  imports = [
    ./cpu.nix
    ./amdgpu.nix
    ./radeon.nix
    ./rocm.nix
  ];
  
  config = mkIf cfg.enable {

    aviallon.programs.nvtop = {
      enable = true;
      backend = [ "amd" ];
    };

    hardware.graphics.enable = true;

    aviallon.hardware.mesa.enable = mkDefault (!cfg.useProprietary);
  };
}
