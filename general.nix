{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
in
{
  imports = [
    (mkRemovedOptionModule [ "aviallon" "general" "flakes" "enable" ] "Flakes are now enabled by default")
  ];

  options.aviallon.general = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's general tuning";
      type = types.bool;
    };

    minimal = mkEnableOption "minimal installation";
    
    cores = mkOption {
      default = null;
      example = 4;
      description = "Number of physical threads of the machine";
      type = with types; nullOr ints.positive;
    };

    cpuVendor = mkOption {
      default = null;
      example = "amd";
      description = "Vendor of you CPU. Either AMD or Intel";
      type = types.str;
    };
    
    cpuArch = mkOption {
      default = "x86-64";
      example = "x86-64-v2";
      description = "Set CPU arch used in overlays, ...";
      type = types.str;
    };
    cpuTune = mkOption {
      default = "generic";
      example = "sandybridge";
      description = "Set CPU tuning for compilers";
      type = types.str;
    };
    unsafeOptimizations = mkEnableOption "unsafe system tuning";
    debug = mkEnableOption "debug-specific configuration";
  };

  config = mkIf cfg.enable {
    # Set your time zone.
    time.timeZone = "Europe/Paris";

    # Select internationalisation properties.
    i18n = {
      defaultLocale = "fr_FR.UTF-8";
    };

    console = {
      keyMap = "fr-pc";
      font = "Lat2-Terminus16";
    };

    aviallon.boot.cmdline = mkIf cfg.unsafeOptimizations {
      mitigations = "off";
    };

    powerManagement.cpuFreqGovernor = mkDefault "schedutil";

    # zram is so usefull, we should always have it enabled.
    zramSwap = {
      enable = true;
      priority = 10000;
      memoryPercent = 100;
      algorithm = "zstd";
    };

    environment.noXlibs = mkIf (cfg.minimal && (!desktopCfg.enable)) true;
  };

}
