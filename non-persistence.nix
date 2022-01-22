{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.non-persistence;
in
{
  options.aviallon.non-persistence = {
    enable = mkEnableOption "non-persitent root"; 
  };
  config = mkIf cfg.enable {
    environment.etc = {
      nixos.source = "/persist/etc/nixos";
      NIXOS.source = "/persist/etc/NIXOS";
      machine-id.source = "/persist/etc/machine-id";
    };
  };
}
