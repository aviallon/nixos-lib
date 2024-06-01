{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.programs.nvtop;
in {
  options.aviallon.programs.nvtop = {
    enable = mkEnableOption "nvtop";
    nvidia = mkEnableOption "Nvidia GPU with proprietary drivers is used";
    package = mkOption {
      internal = true;
      description = "Which nvtop package to use";
      default = pkgs.nvtopPackages.amd;
      type = myLib.types.package';
    };
  };

  config = mkIf cfg.enable {
    # If an Nvidia GPU is used, use the full nvtop package
    aviallon.programs.nvtop.package = mkIf cfg.nvidia pkgs.nvtop;

    environment.systemPackages = [
      cfg.package
    ];
  };
}
