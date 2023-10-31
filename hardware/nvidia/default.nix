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
    useProprietary = mkEnableOption "nvidia proprietary drivers" // {
      default = (cfg.variant == "proprietary");
    };
    variant = mkOption {
      type = with types; enum [ "proprietary" "open" "nouveau" ];
      description = "What driver variant to use";
      default = "proprietary";
      example = "nouveau";
    };
  };

  config = mkIf cfg.enable {
    hardware.opengl.driSupport32Bit = true;

    aviallon.programs.nvtop.enable = true;

    aviallon.hardware.nvidia.useProprietary = mkForce ( cfg.variant == "proprietary" );
  };

}
