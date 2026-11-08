{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  generalCfg = config.aviallon.general;
  throttledService = "throttled";
  intelCfg = config.aviallon.hardware.intel;
in {
  options.aviallon.hardware.intel.bdProchot = mkOption {
    description = "Wether to enable, disable or do nothing with BD PROCHOT";
    default = null;
    type = with types; nullOr bool;
    example = false;
  };
  
  config = mkIf (generalCfg.cpu.vendor == "intel") {
    aviallon.boot.cmdline = {
      "intel_pstate" = "passive";
    };

    services.throttled.enable = generalCfg.unsafeOptimizations;
    services.thermald.enable = true;
    
    services.throttled.extraConfig = concatStringsSep "\n" ([]
      ++ optional (intelCfg.bdProchot != null) ''
        [AC]
        Disable_BDPROCHOT: ${if (!intelCfg.bdProchot) then "True" else "False"}
        ''
    );

    systemd.services.${throttledService} = {
      bindsTo = [ "ac-power.target" ];
      conflicts = [ "thermald.service" ];
    };

    systemd.services.thermald = mkIf config.services.thermald.enable {
      wantedBy = [ "battery-power.target" ];
    };
  };
}
