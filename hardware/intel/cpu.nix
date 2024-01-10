{config, pkgs, lib, ...}:
with lib;
let
  generalCfg = config.aviallon.general;
  throttledService = "throttled";
in {
  config = mkIf (generalCfg.cpu.vendor == "intel") {
    aviallon.boot.cmdline = {
      "intel_pstate" = "passive";
    };

    services.throttled.enable = generalCfg.unsafeOptimizations;
    services.thermald.enable = true;

    systemd.services.${throttledService} = {
      bindsTo = [ "ac-power.target" ];
      conflicts = [ "thermald.service" ];
    };

    systemd.services.thermald = mkIf config.services.thermald.enable {
      wantedBy = [ "battery-power.target" ];
    };
  };
}
