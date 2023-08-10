{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.filesystems;
  
  ioSchedType = types.enum [ "bfq" "kyber" "mq-deadline" "none" null ];
in
{
  imports = [
    ./filesystems
  ];

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
    resumeDevice = mkOption {
      default = null;
      description = "Swap device used for hibernation/resuming.";
      example = "LABEL=nixos-swap";
      type = types.nullOr types.str;
    };
  };

  config = mkIf cfg.enable {

    services.lvm = mkIf cfg.lvm {
      boot.thin.enable = true;
      dmeventd.enable = true;
      boot.vdo.enable = config.aviallon.boot.kvdo.enable;
    };
    boot.initrd.kernelModules = ifEnable cfg.lvm [
      "dm-cache" "dm-cache-smq" "dm-cache-mq" "dm-cache-cleaner"
    ];
    boot.kernelModules = []
      ++ optionals cfg.lvm [ "dm-cache" "dm-cache-smq" "dm-persistent-data" "dm-bio-prison" "dm-clone" "dm-crypt" "dm-writecache" "dm-mirror" "dm-snapshot" ]
      ++ optionals config.aviallon.boot.kvdo.enable [ "kvdo" ]
    ;

    aviallon.boot.cmdline = {
      resume =
        if isNull cfg.resumeDevice
          then "none"
          else cfg.resumeDevice
        ;
    };


    boot.supportedFilesystems = [ "ntfs" "ext4" "vfat" "exfat" ];

    aviallon.filesystems.udevRules = mkBefore (concatLists [
      (optional (!(builtins.isNull cfg.hddScheduler))
        ''ACTION!="remove", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="${cfg.hddScheduler}"''
      )
      (optional (!(builtins.isNull cfg.slowFlashScheduler))
        ''
        SUBSYSTEM!="block", GOTO="end"
        KERNEL!="sd[a-z]|nvme[0-9]*n[0-9]*|mmcblk[0-9]", GOTO="end"
        ATTR{queue/rotational}!="0", GOTO="end"
        
        ACTION!="remove", ATTR{queue/scheduler}="${cfg.slowFlashScheduler}"

        # If possible, disable back_seek_penalty as it is effectively null on SSDs
        ACTION!="remove", TEST=="queue/iosched/back_seek_penalty", ATTR{queue/iosched/back_seek_penalty}="0"

        # BEGIN: NCQ disabled
          ACTION!="remove", ATTR{device/queue_depth}!="1", GOTO="no_ncq_end"

          # Increase maximum requests in software queue
          ACTION!="remove", ATTR{queue/nr_requests}="256"

          # If possible, prefer throughput over latency
          ACTION!="remove", TEST=="queue/iosched/low_latency", ATTR{queue/iosched/low_latency}="1"

          LABEL="no_ncq_end"
        # END: NCQ disabledf
        
        LABEL="end"
        ''
      )
      (optional (!(builtins.isNull cfg.nvmeScheduler))
        ''ACTION!="remove", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]", ATTR{queue/scheduler}="${cfg.nvmeScheduler}"''
      )
      (optional cfg.queuePriority
        ''ACTION!="remove", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{device/ncq_prio_supported}=="1", ATTR{device/ncq_prio_enable}="1"''
      )
    ]);

    boot.initrd.services.udev.rules = concatStringsSep "\n" cfg.udevRules;

    services.udev = {
      extraRules = concatStringsSep "\n" cfg.udevRules;
    };

    boot.tmp.useTmpfs = true;
    boot.tmp.tmpfsSize =
      let
        hasSwap = length config.swapDevices > 0;
      in
        if hasSwap then "150%" else "75%"
      ;

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
