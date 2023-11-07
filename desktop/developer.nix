{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in {
  options.aviallon.developer = {
    enable = mkEnableOption "enable developer mode on this machine";
    virtualbox.unstable = mkEnableOption "use unstable virtualbox";
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
      parted
      gparted
      cpu-x
      nix-index
      lm_sensors
      ethtool
      vulkan-tools
      gh # GitHub CLI

      # Language Servers
      nodePackages.yaml-language-server # Yaml
      nodePackages.bash-language-server # Bash
      nodePackages.intelephense # PHP
      gopls # Go
      ccls # C/C++
      lua-language-server # Lua

      clinfo
      binutils
      cpuset
      gptfdisk # gdisk
    
      gcc
      gnumake
      cmake

      linux-manual man-pages man-pages-posix
      
      linuxHeaders

      # Virtulization tools
      virt-manager
      guestfs-tools
      virt-viewer
      qtemu

      libsForQt5.kdevelop
      unstable.adbfs-rootless

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
        verbatimConfig = ''
          nvram = [ "/run/libvirt/nix-ovmf/AAVMF_CODE.fd:/run/libvirt/nix-ovmf/AAVMF_VARS.fd", "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd" ]
        '';
      };
    };

    
    virtualisation.spiceUSBRedirection.enable = true; # Quality of life
    security.virtualisation.flushL1DataCache = "never"; # We do not care, we are on a dev platform

    virtualisation.virtualbox = {
      host.enable = true;
      host.enableExtensionPack = true;
      host.enableHardening = false; # Causes kernel build failures
    };

    nixpkgs.overlays = []
      ++ optional cfg.virtualbox.unstable (final: prev: {
        virtualbox = final.unstable.virtualbox;
        virtualboxExtpack = final.unstable.virtualboxExtpack;
      })
    ;

    console.enable = true;

    environment.extraOutputsToInstall = [
      "doc" "info" "dev" "debug" "static"
    ];

    aviallon.services.journald.extraConfig = {
      Storage = mkForce "persistent";
    };

    aviallon.boot.configurationLimit = mkDefault 10;

    aviallon.programs.allowUnfreeList = [
      "tabnine" "clion"
      "Oracle_VM_VirtualBox_Extension_Pack" "virtualbox"
      "intelephense"
    ];
  };
}
