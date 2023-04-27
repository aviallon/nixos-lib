{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in {
  config = mkIf (cfg.enable && !cfg.useProprietary) {
    boot.initrd.kernelModules = [ "nouveau" ];

    aviallon.boot.cmdline = {
      "nouveau.perflvl_wr" = 7777;
      "nouveau.pstate" = 1;
      "nouveau.runpm" = 1;
      "nouveau.modeset" = 1;
      "nouveau.config" = "NvBoost=1";
    };

    aviallon.hardware.mesa.enable = mkDefault true;
  };
}
