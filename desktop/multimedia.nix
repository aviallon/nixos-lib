{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ffmpeg-full
      krita
      obs-studio
      scribus
      yt-dlp
    ];
  };
}
