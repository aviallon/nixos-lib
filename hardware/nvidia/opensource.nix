{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in {
  config = mkIf (cfg.enable && !cfg.useProprietary) {
    boot.initrd.kernelModules = [ "nouveau" ];
  };
}
