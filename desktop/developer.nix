{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.developer;
  generalCfg = config.aviallon.general;
in {
  options.aviallon.developer = {
    enable = mkEnableOption "enable developer mode on this machine";
    virtualization.host.enable = (mkEnableOption "hypervisor virtualization services") // { default = true; };
    virtualbox.unstable = mkEnableOption "use unstable virtualbox";
  };
  config = mkIf cfg.enable {
    system.nixos.tags = [ "developer" ];

    programs.direnv.enable = true;
    programs.direnv.loadInNixShell = true;
    programs.bash.promptInit = mkAfter ''
      _direnv_hook() {
        local previous_exit_status=$?;
        trap -- "" SIGINT;
        eval "$(${getBin config.programs.direnv.package}/bin/direnv export bash)";
        trap - SIGINT;
        return $previous_exit_status;
      };
      if ! [[ "''${PROMPT_COMMAND:-}" =~ _direnv_hook ]]; then
        PROMPT_COMMAND="_direnv_hook''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
      fi
    '';
  
    environment.systemPackages = with pkgs; [
      #tabnine
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

      # Virtualization tools
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

    virtualisation.libvirtd = mkIf cfg.virtualization.host.enable {
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

    virtualisation.virtualbox = mkIf cfg.virtualization.host.enable {
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

    boot.initrd.systemd.emergencyAccess = mkIf (config.users.users.root.hashedPassword != null) config.users.users.root.hashedPassword;

    environment.extraOutputsToInstall = [
      "doc" "info" "dev"
    ];

    services.ollama = {
      enable = mkDefault true;
      loadModels = [ "yi-coder:1.5b" ];
      group = "ollama";
      user = "ollama";
      package =
        if config.aviallon.hardware.amd.enable
          then pkgs.unstable.ollama-rocm
        else if (config.aviallon.hardware.nvidia.enable && config.aviallon.hardware.nvidia.variant != "nouveau")
          then pkgs.unstable.ollama-cuda
        else pkgs.unstable.ollama
      ;
    };

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
