{ config, pkgs, lib, ... }:
with lib;
{
  options.aviallon.windows.wine = {
    enable = mkEnableOption "windows executable support on Linux";
  };
  config = {
    environment.systemPackages = with pkgs; [
      bottles
      wineWowPackages.waylandFull
    ];
  };
}
