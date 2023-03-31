{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
in
{
  options.aviallon.hardware = {  };

  imports = [
    ./amd
    ./nvidia
    ./intel
  ];

  config = {

    environment.systemPackages = []
      ++ optional (cfg.amd.enable && cfg.nvidia.enable) pkgs.nvtop
      ++ optional cfg.amd.enable pkgs.nvtop-amd
      ++ optional cfg.nvidia.enable pkgs.nvtop-nvidia
    ;

    boot.kernel.sysctl = {

      # Why: https://www.phoronix.com/news/Ryzen-Segv-Response
      # Workaround: https://forums.gentoo.org/viewtopic-p-2605135.html#2605135
      "kernel.randomize_va_space" = mkIf (generalCfg.cpuVendor == "amd" && generalCfg.cpuArch == "znver1" ) (warn "Disable Adress Space Layout Randomization on Ryzen 1 CPU" 0);
    };

  };

}
