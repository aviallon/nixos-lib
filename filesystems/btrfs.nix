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
    autoScrub = mkOption {
      type = types.bool;
      default = true;
      description = "Wether to enable automatic scrubbing";
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
      enable = true;
      fileSystems = [ "/" ];
    };
    systemd.services.duperemove = {
      script = ''
      mkdir -p $DATA_DIR
      exec ${pkgs.duperemove}/bin/duperemove --io-threads=${toString cfg.autoDedup.ioThreads} --cpu-threads=${toString cfg.autoDedup.cpuThreads} -h --dedupe-options=fiemap,same --hashfile=$DATA_DIR/hashes.db -v -Ard "$@"
      '';
      scriptArgs = concatStringsSep " " cfg.autoDedup.paths;
      # %S : state
      environment = {
        DATA_DIR = "%S/duperemove";
      };
      serviceConfig = {
        CPUQuota = "50%";
        Nice = 19;
        MemoryAccounting = true;
        MemoryHigh = "33%";
        MemoryMax = "50%";
        IOWeight = 10;
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
