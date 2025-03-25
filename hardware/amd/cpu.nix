{config, pkgs, lib, ...}:
with lib;
let
  generalCfg = config.aviallon.general;
  enableZenpower = (! isNull (builtins.match "znver[1-3]" generalCfg.cpu.arch)) && (versionOlder kernelVersion "6.13");
  kernelVersion = getVersion config.boot.kernelPackages.kernel;
in {
  config = mkIf (generalCfg.cpu.vendor == "amd") {
    boot.kernel.sysctl = {

      # Why: https://www.phoronix.com/news/Ryzen-Segv-Response
      # Workaround: https://forums.gentoo.org/viewtopic-p-2605135.html#2605135
      "kernel.randomize_va_space" = mkIf (generalCfg.cpu.arch == "znver1" ) (warn "Disable Adress Space Layout Randomization on Ryzen 1 CPU" 0);
    };

    aviallon.boot.cmdline = {
      "amd_pstate" =
        if versionAtLeast kernelVersion "6.4" then
          "guided"
        else if versionAtLeast kernelVersion "6.3" then
          "active"
        else
          "passive"
        ;
    } // optionalAttrs (generalCfg.cpu.arch == "znver2") {
      # Required for Zen 2
      "amd_pstate.shared_memory" = 1;
    };

    aviallon.boot.patches = mkIf config.aviallon.optimizations.enable {};

    boot.extraModulePackages = with config.boot.kernelPackages; [] 
      ++ optional enableZenpower (info "enable zenpower for Ryzen [1-3] CPU" zenpower)
    ;

    boot.kernelModules = []
      ++ optional enableZenpower "zenpower"
    ;

    boot.blacklistedKernelModules = []
      ++ optional enableZenpower "k10-temp" # Superseded by zenpower
    ;
  };
}

