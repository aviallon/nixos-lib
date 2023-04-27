{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in {
  config = mkIf (cfg.enable && cfg.kernelDriver == "radeon") {
    boot.initrd.kernelModules = [ "radeon" ];

    aviallon.boot.cmdline = {
    };

    environment.systemPackages = with pkgs; [
      
    ];

    services.xserver.videoDrivers = [
      "modesetting"
    ];

    environment.variables = {};
  };
}
