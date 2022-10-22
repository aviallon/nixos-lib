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
      jetbrains.clion
      # adbfs-rootless
    ];

    documentation = {
      dev.enable = true;
    };

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore"; # We are doing development, not a server
      qemu = {
        package = pkgs.qemu_full;
        ovmf.enable = true;
        ovmf.package = pkgs.OVMFFull;
        swtpm.enable = true;
      };
    };
    virtualisation.spiceUSBRedirection.enable = true; # Quality of life
    security.virtualisation.flushL1DataCache = "never"; # We do not care, we are on a dev platform

    virtualisation.virtualbox.host.enable = true;
    virtualisation.virtualbox.host.enableExtensionPack = true;

    environment.extraOutputsToInstall = [
      "doc" "info" "devdoc"
    ];

    aviallon.programs.allowUnfreeList = [
      "tabnine" "clion"
      "Oracle_VM_VirtualBox_Extension_Pack" "virtualbox"
    ];
  };
}
