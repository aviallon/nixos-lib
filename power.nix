{ config, pkgs, lib, myLib, ... }:
with lib;
let
  generalCfg = config.aviallon.general;
  cfg = config.aviallon.power;
  undervoltType = with types; nullOr (addCheck int (x: (x < 0 && x > -200)));
in {
  options.aviallon.power = {
    enable = mkOption {
      default = true;
      example = false;
      type = types.bool;
      description = "Wether to enable power related tuning";
    };
    policy = mkOption {
      default = "performance";
      example = "efficiency";
      description = "What to optimize towards";
      type = types.enum [ "performance" "efficiency" ];
    };
    powerLimit = {
      enable = mkEnableOption "power limiting";
      ac = {
        cpu = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Power limit when on AC. Set to null for unlimited.";
          example = 35;
        };
        cpuBoost = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Boost power limit when on AC. Set to null for unlimited.";
          example = 65;
        };
      };
      battery = {
        cpu = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Power limit when on battery. Set to null for unlimited.";
          example = 15;
        };
        cpuBoost = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Boost power limit when on battery. Set to null for unlimited.";
          example = 35;
        };
      };
    };
    temperature = {
      enable = mkEnableOption "Temperature limitting";
      ac = {
        cpu = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Temperature limit when on AC.";
          example = 100;
        };
      };
      battery = {
        cpu = mkOption {
          default = null;
          type = types.nullOr types.int;
          description = "Temperature limit when on battery.";
          example = 60;
        };
      };
    };
    undervolt.cpu = {
      enable = mkEnableOption "CPU undervolting. Unstability may be caused when using this option.";
      coreOffset = mkOption {
        default = null;
        example = -25;
        description = "CPU core offset in mV";
        type = undervoltType;
      };
      cacheOffset = mkOption {
        default = cfg.undervolt.cpu.coreOffset;
        example = -25;
        description = "Cache offset in mV";
        type = undervoltType;
      };
      iGPUOffset = mkOption {
        default = null;
        example = -15;
        description = "iGPU offset in mV";
        type = undervoltType;
      };
    };
    undervolt.gpu = {
      enable = mkEnableOption "GPU undervolting.";
    };
  };
  config = mkIf cfg.enable {
    systemd.targets.ac-power = {
      description = "Target is active when AC is plugged-in.";
      conflicts = [ "battery-power.target" ];
      unitConfig = {
        ConditionACPower = true;
      };
    };
    
    systemd.targets.battery-power = {
      description = "Target is active when power is drawn from a battery.";
      conflicts = [ "ac-power.target" ];
      unitConfig = {
        ConditionACPower = false;
      };
    };

    services.udev.extraRules = ''
      ACTION!="remove", KERNEL=="AC*", SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop ac-power.target"
      ACTION!="remove", KERNEL=="AC*", SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac-power.target"
      
      ACTION!="remove", KERNEL=="BAT*", SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", RUN+="${pkgs.systemd}/bin/systemctl start battery-power.target"
      ACTION!="remove", KERNEL=="BAT*", SUBSYSTEM=="power_supply", ATTR{status}=="Charging", RUN+="${pkgs.systemd}/bin/systemctl stop battery-power.target"
    '';
  
    systemd.services.undervolt-intel = {
      script = ""
        + "${pkgs.undervolt}/bin/undervolt"
        + (optionalString (! isNull cfg.undervolt.cpu.coreOffset ) " --core ${toString cfg.undervolt.cpu.coreOffset}")
        + (optionalString (! isNull cfg.undervolt.cpu.cacheOffset ) " --cache ${toString cfg.undervolt.cpu.cacheOffset}")
        + (optionalString (! isNull cfg.undervolt.cpu.iGPUOffset ) " --gpu ${toString cfg.undervolt.cpu.iGPUOffset}")
      ;
      serviceConfig = {
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
      description = "Undervolt Intel CPUs with supported firmware.";
      enable = cfg.undervolt.cpu.enable && (generalCfg.cpuVendor == "intel");
    };

    systemd.services.intel-powerlimit-ac = {
      script = "${pkgs.undervolt}/bin/undervolt"
        + optionalString (! isNull cfg.powerLimit.ac.cpu ) " --power-limit-long ${toString cfg.powerLimit.ac.cpu} 28"
        + optionalString (! isNull cfg.powerLimit.ac.cpuBoost ) " --power-limit-short ${toString cfg.powerLimit.ac.cpuBoost} 0.1"
        + optionalString (! isNull cfg.temperature.ac.cpu ) " --temp ${toString cfg.temperature.ac.cpu}"
      ;
      unitConfig = {
        ConditionACPower = true;
      };
      serviceConfig = {
        RemainAfterExit = true;
      };
      wantedBy = [ "ac-power.target" ];
      description = "Set power limit of Intel CPUs with supported firmware. AC mode.";
      partOf = [ "ac-power.target" ];
      enable = (cfg.powerLimit.enable || cfg.temperature.enable) && (generalCfg.cpuVendor == "intel");
    };
    
    systemd.services.intel-powerlimit-battery = {
      script = "${pkgs.undervolt}/bin/undervolt"
        + optionalString (! isNull cfg.powerLimit.battery.cpu ) " --power-limit-long ${toString cfg.powerLimit.battery.cpu} 28"
        + optionalString (! isNull cfg.powerLimit.battery.cpuBoost ) " --power-limit-short ${toString cfg.powerLimit.battery.cpuBoost} 0.1"
        + optionalString (! isNull cfg.temperature.battery.cpu ) " --temp ${toString cfg.temperature.battery.cpu}"
      ;
      unitConfig = {
        ConditionACPower = false;
      };
      serviceConfig = {
        RemainAfterExit = true;
      };
      wantedBy = [ "battery-power.target" ];
      description = "Set power limit of Intel CPUs with supported firmware. Battery mode.";
      partOf = [ "battery-power.target" ];
      enable = (cfg.powerLimit.enable || cfg.temperature.enable) && (generalCfg.cpuVendor == "intel");
    };
    
  };
}
