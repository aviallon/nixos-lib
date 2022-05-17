{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in
{
  imports = [
    ./nvidia
  ];

  options.aviallon.hardware.nvidia = {
    enable = mkEnableOption "enable Nvidia hardware config";
    useProprietary = mkEnableOption "nvidia proprietary drivers";
    saveAllVram = mkEnableOption "back up all VRAM in /tmp before going to sleep. May reduce artifacts after resuming";
  };

  config = mkIf cfg.enable {
    hardware.opengl.driSupport32Bit = true;
  };
}
