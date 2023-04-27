{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.windows.wine;
in {
  options.aviallon.windows.wine = {
    enable = mkEnableOption "windows executable support on Linux";
    package = mkOption {
      description = "Wine package to use";
      type = types.package;
      default = pkgs.wineWowPackages.waylandFull;
      example = pkgs.winePackages.stable;
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bottles
      cfg.package
    ];
  };
}
