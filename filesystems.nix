{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.filesystems;
  
  getSwapDevice = index: ifEnable (length config.swapDevices > index) (elemAt config.swapDevices index);
  firstSwapDevice = getSwapDevice 0;
  resumeDeviceLabel = attrByPath [ "label" ] null firstSwapDevice; 
  
  ioSchedType = types.enum [ "bfq" "kyber" "mq-deadline" "none" null ];
in
{
  options.aviallon.filesystems = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's filesystem tuning";
      type = types.bool;
    };
    hddScheduler = mkOption {
      default = "bfq";
      example = null;
      description = "Automatically set HDDs IO queue algorithm";
      type = ioSchedType;
    };
    slowFlashScheduler = mkOption {
      default = "kyber";
      example = "none";
      description = "Automatically set flash storage IO queue algorithm";
      type = ioSchedType;
    };
    nvmeScheduler = mkOption {
      default = "none";
      example = "kyber";
      description = "Automatically set NVMe IO queue algorithm";
      type = ioSchedType;
    };
    queuePriority = mkOption {
      default = true;
      example = false;
      description = "Automatically enable ncq_prio if it is supported by the SATA device.\nIt may improve latency.";
      type = types.bool;
    };
    udevRules = mkOption {
      default = [];
      example = [ ''ACTION!="remove", SUBSYSTEM=="block", KERNEL=="sda", ATTR{queue/scheduler}="none"'' ];
      description = "Additional udev rules";
      type = types.listOf types.str;
    };
    lvm = mkEnableOption "lvm options required for correct booting";
  };

  config = mkIf cfg.enable {

    services.lvm = mkIf cfg.lvm {
      boot.thin.enable = true;
      dmeventd.enable = true;
    };
    boot.initrd.kernelModules = ifEnable cfg.lvm [
      "dm-cache" "dm-cache-smq" "dm-cache-mq" "dm-cache-cleaner"
    ];
    boot.kernelModules = ifEnable cfg.lvm [ "dm-cache" "dm-cache-smq" "dm-persistent-data" "dm-bio-prison" "dm-clone" "dm-crypt" "dm-writecache" "dm-mirror" "dm-snapshot"];
    aviallon.boot.cmdline = {
      resume = mkIf (! isNull resumeDeviceLabel) (mkDefault "LABEL=${resumeDeviceLabel}");
    };

    fileSystems."/boot".neededForBoot = mkDefault true;

    aviallon.filesystems.udevRules = mkBefore (concatLists [
      (optional (!(builtins.isNull cfg.hddScheduler))
        ''ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}!="none", ATTR{queue/scheduler}="${cfg.hddScheduler}"''
      )
      (optional (!(builtins.isNull cfg.slowFlashScheduler))
        ''ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="${cfg.slowFlashScheduler}"''
      )
      (optional (!(builtins.isNull cfg.nvmeScheduler))
        ''ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="${cfg.nvmeScheduler}"''
      )
      (optional cfg.queuePriority
        ''ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]*", ATTR{device/ncq_prio_supported}=="1", ATTR{device/ncq_prio_enable}="1"''
      )
    ]);

    services.udev = {
      extraRules = concatStringsSep "\n" cfg.udevRules;
      initrdRules = concatStringsSep "\n" cfg.udevRules;
    };

    boot.tmpOnTmpfs = true;

    services.smartd = {
      enable = mkDefault true;
      autodetect = true;
      defaults.autodetected = "-a -o on -s (S/../.././02|L/../../7/04)";
      notifications.mail = {
        enable = true;
        sender = "admin@${config.networking.hostName}.local";
        recipient = "antoine@lesviallon.fr";
      };
      notifications.x11 = {
        enable = true;
        display = ":0";
      };
    };
  };
} 
