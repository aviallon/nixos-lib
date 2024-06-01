{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.programs.nvtop;
in {
  options.aviallon.programs.nvtop = {
    enable = mkEnableOption "nvtop";
    backend = mkOption {
      description = "Which backend to enable";
      type = with types; listOf (enum [ "nvidia" "amd" "intel" "panthor" "panfrost" "msm" ]);
      default = [ "amd" ];
    };
    
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
    aviallon.programs.nvtop.package = mkDefault (
      if (length cfg.backend > 1) then
        pkgs.nvtopPackages.full
      else pkgs.nvtopPackages.${elemAt cfg.backend 0}
    );

    environment.systemPackages = [
      cfg.package
    ];
  };
}
