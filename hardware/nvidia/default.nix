{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in {

  imports = [
    ./vgpu.nix
    ./proprietary.nix
    ./opensource.nix
    ( mkRenamedOptionModule [ "aviallon" "hardware" "nvidia" "saveAllVram" ] [ "aviallon" "hardware" "nvidia" "proprietary" "saveAllVram" ] )
  ];

  options.aviallon.hardware.nvidia = {
    enable = mkEnableOption "enable Nvidia hardware config";
    useProprietary = mkEnableOption "nvidia proprietary drivers";
  };

  config = mkIf cfg.enable {
    hardware.opengl.driSupport32Bit = true;
  };

}
