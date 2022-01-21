{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.laptop;
in {
  options.aviallon.laptop = {
    enable = mkOption {
      default = false;
      example = true;
      type = types.bool;
      description = "Enable aviallon's laptop configuration";
    };
  };

  config = mkIf cfg.enable {
    networking.networkmanager.wifi.powersave = true;
    aviallon.general.unsafeOptimizations = mkOverride 50 true;
  };
}
