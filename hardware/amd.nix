{ config, pkgs, lib, ... }:
with lib;
let
  hardwareCfg = config.aviallon.hardware;
in
{
  config = mkIf (hardwareCfg.gpuVendor == "amd") {
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
