{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  cmdline = config.aviallon.boot.cmdline;
  zswapEnabled = if cmdline ? "zswap.enabled" then cmdline."zswap.enabled" == "Y" else false
in
{
  imports = [
    (mkRemovedOptionModule [ "aviallon" "general" "flakes" "enable" ] "Flakes are now enabled by default")
    (mkRenamedOptionModule [ "aviallon" "general" "cpuVendor" ] [ "aviallon" "general" "cpu" "vendor" ])
    (mkRenamedOptionModule [ "aviallon" "general" "cpuArch" ] [ "aviallon" "general" "cpu" "arch" ])
    (mkRenamedOptionModule [ "aviallon" "general" "cpuTune" ] [ "aviallon" "general" "cpu" "tune" ])
    (mkRenamedOptionModule [ "aviallon" "general" "cores" ] [ "aviallon" "general" "cpu" "threads" ])
  ];

  options.aviallon.general = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's general tuning";
      type = types.bool;
    };

    minimal = mkEnableOption "minimal installation";
    
    cpu = {
      threads = mkOption {
        default = null;
        example = 4;
        description = "Number of physical threads of the machine";
        type = with types; nullOr ints.positive;
      };
    
      vendor = mkOption {
        default = null;
        example = "amd";
        description = "Vendor of you CPU. Either AMD or Intel";
        type = types.str;
      };
    
      arch = mkOption {
        default = 
          if cfg.cpu.x86.level >= 2 then
            "x86-64-v${toString cfg.cpu.x86.level}"
          else
            "x86-64"
          ;
        example = "x86-64-v2";
        description = "Set CPU arch used in overlays, ...";
        type = types.str;
      };
      tune = mkOption {
        default = "generic";
        example = "sandybridge";
        description = "Set CPU tuning for compilers";
        type = types.str;
      };
      
      caches = {
        l1d = mkOption {
          default = null;
          example = 64;
          description = "CPU L1 (data) cache size in kB";
          type = with types; nullOr ints.positive;
        };
        l1i = mkOption {
          default = null;
          example = 64;
          description = "CPU L1 (instruction) cache size in kB";
          type = with types; nullOr ints.positive;
        };
        lastLevel = mkOption {
          default = null;
          example = 1024;
          description = "Last-level (typ. L3) CPU cache size in kB";
          type = with types; nullOr ints.positive;
        };
        cacheLine = mkOption {
          default = null;
          example = 64;
          description = "Cache-line size in bytes (can be retrieved using `/sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size`)";
          type = with types; nullOr ints.positive;
        };
      };
      
      x86 = {
        level = mkOption {
          default = 1;
          example = 3;
          description = "Set supported x86-64 level";
          type = with types; addCheck int (n: n >= 1 && n <= 4);
        };
      };
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
      keyMap = mkIf (!config.console.useXkbConfig) "fr-pc";
      useXkbConfig = mkDefault true;
      font = "Lat2-Terminus16";
    };

    boot.initrd.systemd.contents = mkIf (config.boot.initrd.systemd.enable && !config.console.earlySetup) {
      "/etc/kbd/consolefonts".source = "${pkgs.kbd}/share/consolefonts";
    };

    aviallon.boot.cmdline = mkIf cfg.unsafeOptimizations {
      mitigations = "off";
      #"zswap.enabled" = "Y";
      "zswap.shrinker_enabled" = "Y";
      "zswap.compressor" = "zstd";
      "zswap.pool" = "zsmalloc";
    };

    assertions = [
      {
        assertion = zswapEnabled -> (!config.zramSwap.enable);
        message = "If using zswap, you should disable zram, as both conflict with each other";
      }
    ];

    zramSwap = {
      enable = !zswapEnabled;
      priority = 1000;
      memoryPercent = 50;
    };

    powerManagement.cpuFreqGovernor = mkDefault "schedutil";

    environment.noXlibs = mkIf (cfg.minimal && (!desktopCfg.enable)) true;
  };

}
