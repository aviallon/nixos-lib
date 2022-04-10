{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.laptop;
in {
  options.aviallon.laptop = {
    enable = mkOption {
      default = false;
      example = true;
      type = types.bool;
      description = "Enable aviallon's laptop configuration";
    };
    power-manager = mkOption {
      default = "tlp";
      example = "power-profiles-daemon";
      description = "Change service used to manage power consumption on laptop";
      type = types.enum [ "tlp" "power-profiles-daemon" false ];
    };
    tweaks = {
      pcieAspmForce = mkEnableOption "hardcore tweaks to power consumption. Warning: Might be dangerous to use.";
    };
  };

  config = mkIf cfg.enable {
    networking.networkmanager.wifi.powersave = mkDefault true;
    aviallon.general.unsafeOptimizations = mkOverride 50 true;

    hardware.sensor.iio.enable = mkDefault true;

    aviallon.boot.cmdline = {
      "i915.enable_fbc" = 1;
      "i915.enable_gvt" = 1;

      # Les power consumption against some performance
      "workqueue.power_efficient" = "";
      nohz = "on";

      pcie_aspm = mkIf cfg.tweaks.pcieAspmForce "force";
    };


    systemd.services.aspm-force-enable = let
      aspm_enable = pkgs.callPackage ./packages/aspm_enable { };
    in {
      serviceConfig = {
        ExecStart = [
          "${aspm_enable}/bin/aspm_enable"
        ];
        Type = "simple";
      };
      wantedBy = [ "multi-user.target" ];
      description = "Force-enable PCIe ASPM";
      enable = cfg.tweaks.pcieAspmForce;
    };

    services.tlp.enable = (cfg.power-manager == "tlp");
    services.power-profiles-daemon.enable = (cfg.power-manager == "power-profiles-daemon");
    services.tp-auto-kbbl.enable = mkDefault true;
    powerManagement.powertop.enable = mkDefault true;
  };
}
