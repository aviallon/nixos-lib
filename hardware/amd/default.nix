{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
  myMesa = if generalCfg.unsafeOptimizations then pkgs.mesaOptimized else pkgs.mesa;
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
  ];
  
  config = mkIf cfg.enable {
    programs.corectrl.enable = mkIf generalCfg.unsafeOptimizations true;

    hardware.opengl = {
      enable = true;
      package = with pkgs; myMesa.drivers;
      package32 = with pkgs; myMesa.drivers;
      extraPackages = with pkgs; mkIf (!cfg.useProprietary) (mkAfter [
        (hiPrio myMesa)
      ]);
      extraPackages32 = with pkgs.driversi686Linux; mkIf (!cfg.useProprietary) [
        (hiPrio myMesa)
      ];
    };
  };
}
