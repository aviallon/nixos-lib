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
    aviallon.general.unsafeOptimizations = mkOverride 15 true;

    hardware.sensor.iio.enable = mkDefault true;
    location.provider = "geoclue2";

    aviallon.boot.cmdline = {
      # Less power consumption vs some performance loss
      "workqueue.power_efficient" = "1";
      nohz = "on";

      # To save power, batch RCU callbacks and flush after delay, memory pressure or callback list growing too big.
      "rcutree.enable_rcu_lazy" = "1";

      # Enable lazy preempt by default for kernels newer than 6.13
      "preempt" = mkIf (config.boot.kernelPackages.kernelAtLeast "6.13") "lazy";

      pcie_aspm = mkIf cfg.tweaks.pcieAspmForce "force";
    };

    boot.kernel.sysctl = {
      "vm.laptop_mode" = "5";

      # Disable hard-lockup detector
      "kernel.nmi_watchdog" = "0";
    };

    systemd.services.nixos-upgrade = {
      unitConfig = {
        ConditionACPower = true;
      };
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
    powerManagement.powertop.enable = mkDefault true;
    systemd.services.powertop = mkIf config.powerManagement.powertop.enable {
      serviceConfig.ExecStart = let
        script = pkgs.writeShellScriptBin "powertop-auto-tune" ''
          ${pkgs.powertop}/bin/powertop --auto-tune

          # Disable power-saving for HID devices (i.e., keyboard and mouse, as it is makes them frustrating to use)
          HIDDEVICES=$(ls /sys/bus/usb/drivers/usbhid | grep -oE '^[0-9]+-[0-9\.]+' | sort -u)
          for i in $HIDDEVICES; do
            echo -n "Enabling " | cat - /sys/bus/usb/devices/$i/product
            echo 'on' > /sys/bus/usb/devices/$i/power/control
          done
        '';
      in mkOverride 10 "${script}/bin/powertop-auto-tune";
    };
  };
}
