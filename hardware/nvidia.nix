{ config, pkgs, lib, ... }:
with lib;
let
  hardwareCfg = config.aviallon.hardware;
in
{
  config = mkIf (hardwareCfg.gpuVendor == "nvidia") {
    boot.initrd.kernelModules = [ "nouveau" ];
  };
}
