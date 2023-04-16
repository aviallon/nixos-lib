{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.developer;
in {
  options.aviallon.developer = {
    enable = mkEnableOption "enable developer mode on this machine";
  };
  config = mkIf cfg.enable {
    system.nixos.tags = [ "developer" ];
  
    environment.systemPackages = with pkgs; [
      tabnine
      numactl
      schedtool
      stress
      sqlite
      hwloc
      bind
      git-cola
      virt-manager-qt
      qtemu
      parted
      gparted
      cpu-x
      nix-index
      lm_sensors
      ethtool
      gh # GitHub CLI

      linux-manual man-pages man-pages-posix
      
      linuxHeaders

      libsForQt5.kdevelop
      jetbrains.clion
      # adbfs-rootless

      amdctl
    ];

    programs.git.package = pkgs.gitFull;

    documentation = {
      dev.enable = true;
      nixos.includeAllModules = true;
      nixos.enable = true;
      man.enable = true;
    };

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore"; # We are doing development, not a server
      qemu = {
        package = pkgs.qemu_full;
        ovmf.enable = true;
        ovmf.packages = [ pkgs.OVMFFull ];
        swtpm.enable = true;
      };
    };
    virtualisation.spiceUSBRedirection.enable = true; # Quality of life
    security.virtualisation.flushL1DataCache = "never"; # We do not care, we are on a dev platform

    virtualisation.virtualbox = {
      host.enable = true;
      host.enableExtensionPack = true;
      host.enableHardening = false; # Causes kernel build failures
    };

    environment.extraOutputsToInstall = [
      "doc" "info" "dev" "debug" "static"
    ];

    aviallon.boot.configurationLimit = mkDefault 10;

    aviallon.programs.allowUnfreeList = [
      "tabnine" "clion"
      "Oracle_VM_VirtualBox_Extension_Pack" "virtualbox"
    ];
  };
}
