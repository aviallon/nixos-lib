{config, pkgs, lib, ...}:
with lib;
let
  generalCfg = config.aviallon.general;
  throttledService = "lenovo_fix";
in {
  config = mkIf (generalCfg.cpuVendor == "intel") {
    aviallon.boot.cmdline = {
      "intel_pstate" = "passive";
    };

    services.throttled.enable = generalCfg.unsafeOptimizations;
    services.thermald.enable = !generalCfg.unsafeOptimizations;

    systemd.services.${throttledService} = {
      bindsTo = [ "ac-power.target" ];
      conflicts = [ "thermald.service" ];
    };

    systemd.services.thermald = {
      wantedBy = [ "battery-power.target" ];
    };
  };
}
