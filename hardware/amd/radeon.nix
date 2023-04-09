{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.amd;
  devCfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
  myMesa = if generalCfg.unsafeOptimizations then pkgs.mesaOptimized else pkgs.mesa;
in {
  config = mkIf (cfg.enable && cfg.kernelDriver == "radeon") {
    boot.initrd.kernelModules = [ "radeon" ];

    aviallon.boot.cmdline = {
    };

    environment.systemPackages = with pkgs; [
      
    ];

    services.xserver.videoDrivers = [
      "radeon"
    ];

    environment.variables = {};
  };
}
