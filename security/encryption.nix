{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.security.encryption;
in {
  options.aviallon.security.encryption = {
    enable = mkEnableOption "encryption-related tools and programs";
    cryptsetup.package = mkOption {
      description = "Which cryptsetup package to use";
      type = types.path;
      default = pkgs.cryptsetup;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cfg.cryptsetup.package
    ];
  };
}