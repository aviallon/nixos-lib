{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.filesystems;
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
  };

  config = mkIf cfg.enable {

    services.udev =
      let
        udevRules = concatStringsSep "\n" (
          concatLists [
            (optional (!(builtins.isNull cfg.hddScheduler))
              ''ACTION=="add|change" SUBSYSTEM=="block", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}!="none", ATTR{queue/scheduler}="${cfg.hddScheduler}"''
            )
            (optional (!(builtins.isNull cfg.slowFlashScheduler))
              ''ACTION=="add|change" SUBSYSTEM=="block", KERNEL=="sd[a-z]*|nvme[0-9]*n[0-9]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="${cfg.slowFlashScheduler}"''
            )
            (optional (!(builtins.isNull cfg.nvmeScheduler))
              ''ACTION=="add|change" SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="${cfg.nvmeScheduler}"''
            )
          ]
        );
      in
      {
        extraRules = udevRules;
        initrdRules = udevRules;
      };


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
