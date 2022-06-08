{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.developer;
in {
  options.aviallon.developer = {
    enable = mkEnableOption "enable developer mode on this machine";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      tabnine
      numactl
      schedtool
      stress
      sqlite
      hwloc
      bind
      git-cola
      # adbfs-rootless
    ];

    documentation = {
      dev.enable = true;
    };

    aviallon.programs.allowUnfreeList = [
      "tabnine"
    ];
  };
}
