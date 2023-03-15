{config, pkgs, lib, ...}:
with lib;
let
  generalCfg = config.aviallon.general;
  cpuIsZen = ! isNull (builtins.match "znver[0-9]" generalCfg.cpuArch);
in {
  config = mkIf (generalCfg.cpuVendor == "amd") {
    boot.kernel.sysctl = {

      # Why: https://www.phoronix.com/news/Ryzen-Segv-Response
      # Workaround: https://forums.gentoo.org/viewtopic-p-2605135.html#2605135
      "kernel.randomize_va_space" = mkIf (generalCfg.cpuArch == "znver1" ) (warn "Disable Adress Space Layout Randomization on Ryzen 1 CPU" 0);
    };

    aviallon.boot.cmdline = {
      "amd_pstate" = "passive";
    } // optionalAttrs (generalCfg.cpuArch == "znver2") {
      # Required for Zen 2
      "amd_pstate.shared_memory" = 1;
    };

    boot.extraModulePackages = with config.boot.kernelPackages; [] 
      ++ optional cpuIsZen (info "enable zenpower for Ryzen CPU" zenpower)
    ;

    boot.kernelModules = []
      ++ optional cpuIsZen "zenpower"
    ;

    boot.blacklistedKernelModules = []
      ++ optional cpuIsZen "k10-temp" # Superseded by zenpower
    ;
  };
}

