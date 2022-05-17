{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
in
{
  options.aviallon.hardware.amd = {
    enable = mkEnableOption "AMD gpus";
  };
  
  config = mkIf (cfg.enable) {
    boot.initrd.kernelModules = [ "amdgpu" ];

    aviallon.boot.cmdline = {}
      # for Southern Islands (SI ie. GCN 1) cards
      // { "radeon.si_support" = 0;
      "amdgpu.si_support" = 1; }
      # for Sea Islands (CIK ie. GCN 2) cards
      // { "radeon.cik_support" = 0;
       "amdgpu.cik_support" = 1; }
    ;

    hardware.opengl.extraPackages = with pkgs; [
      rocm-opencl-icd
      rocm-opencl-runtime
    ];
  };
}
