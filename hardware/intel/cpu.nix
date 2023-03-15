{config, pkgs, lib, ...}:
with lib;
let
  generalCfg = config.aviallon.general;
in {
  config = mkIf (generalCfg.cpuVendor == "intel") {
    aviallon.boot.cmdline = {
      "intel_pstate" = "passive";
    };
  };
}
