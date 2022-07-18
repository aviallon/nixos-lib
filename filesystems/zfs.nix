{config, lib, pkgs, ...}:
with lib;
let
  cfg = config.aviallon.filesystems.zfs;
in {
  options.aviallon.filesystems.zfs = {
    enable = mkEnableOption "ZFS support";
  };

  config = mkIf cfg.enable {
    boot.initrd.supportedFilesystems = ["zfs"]; # boot from zfs
    boot.supportedFilesystems = [ "zfs" ];

    aviallon.filesystems.udevRules = mkAfter [
      # ZFS doesn't like additional schedulers
      ''SUBSYSTEM=="block", ACTION!="remove", KERNEL=="sd[a-z]*[0-9]*|mmcblk[0-9]*p[0-9]*|nvme[0-9]*n[0-9]*p[0-9]*", ENV{ID_FS_TYPE}=="zfs_member", ATTR{../queue/scheduler}="none"''
    ];
    
    services.zfs.autoScrub.enable = true;
    services.zfs.autoSnapshot.enable = true;

    # Can cause issues with ZFS
    boot.kernelParams = [ "nohibernate" ];
  };
}
