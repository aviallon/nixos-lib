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
    assertions = [
      { assertion = hasAttr "/persist" config.fileSystems;
        message = "A /persist partition is needed for non-persistence";
      }
      { assertion = hasAttr "/var/log" config.fileSystems;
        message = "A /var/log separate parition is needed to avoid missing early logs.";
      }
    ];

    environment.etc = {
      nixos.source = "/persist/etc/nixos";
      NIXOS.source = "/persist/etc/NIXOS";
      machine-id.source = "/persist/etc/machine-id";
    };

    boot.tmpOnTmpfs = true;

    fileSystems = {
      "/var/log" = {
        neededForBoot = true;
        autoFormat = true;
        label = "nixos-persistent-logs";
      };
      "/persist" = {
        neededForBoot = true;
        label = "nixos-persistent-data";
      };
    };
  };
}
