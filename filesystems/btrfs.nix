{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.filesystems.btrfs;
  #fsCfg = config.fileSystems;
  btrfsPaths = [ "/" ];
#  btrfsPaths = filterAttrs (n: v: v.fsType == "btrfs") fsCfg;
  generalCfg = config.aviallon.general;
in {
  options.aviallon.filesystems.btrfs = {
    enable = mkEnableOption "BTRFS support";
    autoScrub = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Wether to enable automatic scrubbing";
      };
      paths = mkOption {
        type = with types; nonEmptyListOf path;
        default = btrfsPaths;
        description = "What paths to scrub. Must be a btrfs mount point.";
      };
    };
    autoDedup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Wether to enable automatic deduplication";
      };
      paths = mkOption {
        type = with types; nonEmptyListOf path;
        default = btrfsPaths;
        description = "What paths to deduplicate. Underlying filesystem must support extent based deduplication.";
      };
      cpuThreads = mkOption {
        type = with types; ints.positive;
        default = generalCfg.cpu.threads or 4;
        description = "How many threads to use for hashing.";
      };
      ioThreads = mkOption {
        type = with types; ints.positive;
        default = myLib.math.log2 generalCfg.cpu.threads or 4;
        description = "How many threads to use for IO operations";
      };
      interval = mkOption {
        type = with types; str;
        default = "weekly";
        description = "Deduplication periodicity.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.btrfs.autoScrub = {
      enable = cfg.autoScrub.enable;
      fileSystems = cfg.autoScrub.paths;
    };
    systemd.services.duperemove = {
      script = ''
      mkdir -p $DATA_DIR
      exec ${pkgs.duperemove}/bin/duperemove \
        --io-threads=${toString cfg.autoDedup.ioThreads} --cpu-threads=${toString cfg.autoDedup.cpuThreads} \
        --dedupe-options=same \
        --hashfile=$DATA_DIR/hashes.db -h -v -rd "$@"
      '';
      scriptArgs = concatStringsSep " " cfg.autoDedup.paths;
      # %S : state
      environment = {
        DATA_DIR = "%S/duperemove";
      };
      unitConfig = {
        ConditionCPUPressure = "50%";
        ConditionIOPressure = "30%";
      };
      serviceConfig = {
        CPUQuota = "50%";
        CPUWeight = 1;
        Nice = 19;
        MemoryAccounting = true;
        MemoryHigh = "33%";
        MemoryMax = "50%";
        IOWeight = 10;
        ManagedOOMMemoryPressure = "kill";
      };
      requires = [ "local-fs.target" ];
    };
    systemd.timers.duperemove = {
      timerConfig = {
        OnCalendar = cfg.autoDedup.interval;
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
