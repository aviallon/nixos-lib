{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardening;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.hardening = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's hardening";
      type = types.bool;
    };

    hardcore = mkOption {
      default = !desktopCfg.enable;
      example = desktopCfg.enable;
      description = "Enable hardcore hardening, which might break things.";
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
  #  imports = [
  #     (modulesPath + "/profiles/hardened.nix")
  #  ];
    boot.kernelPackages = mkIf cfg.hardcore pkgs.linuxPackages_hardened;
    security.lockKernelModules = mkIf cfg.hardcore (mkOverride 500 true);
    security.protectKernelImage = mkIf cfg.hardcore (mkOverride 500 false); # needed for kexec

    security.apparmor.enable = true;
    services.dbus.apparmor = "enabled";


    boot.kernelParams = [
      # Slab/slub sanity checks, redzoning, and poisoning
      "slub_debug=FZP"

      # Overwrite free'd memory
      "page_poison=1"

      # Enable page allocator randomization
      "page_alloc.shuffle=1"

      # Apparmor https://wiki.archlinux.org/title/AppArmor#Installation
      "lsm=landlock,lockdown,yama,apparmor,bpf"
    ];

    boot.kernel.sysctl = {
    "kernel.yama.ptrace_scope" = lib.mkOverride 500 1;
    "kernel.kptr_restrict" = lib.mkOverride 500 2;

    "net.core.bpf_jit_enable" = lib.mkOverride 500 false;

    "kernel.ftrace_enabled" = lib.mkOverride 500 false;
    };

    security.allowUserNamespaces = mkDefault true;
    boot.blacklistedKernelModules = mkForce [ ];

    nix.allowedUsers = mkIf cfg.hardcore [ "@wheel" ];

    security.audit.enable = true;
    security.auditd.enable = true;

    security.audit.rules = [
      "-a exit,always -F arch=b64 -S execve"
    ];


    systemd.services.dbus.serviceConfig = {
      # Hardening
      CapabilityBoundingSet = [ "CAP_SETGID" "CAP_SETUID" "CAP_SETPCAP" "CAP_SYS_RESOURCE" "CAP_AUDIT_WRITE" ];
      DeviceAllow = [ "/dev/null rw" "/dev/urandom r" ];
      DevicePolicy = "strict";
      IPAddressDeny = "any";
      LimitMEMLOCK = 0;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      ReadOnlyPaths = [ "-/" ];
      RestrictAddressFamilies = [ "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@chown" "~@clock" "~@cpu-emulation" "~@debug" "~@module" "~@mount" "~@obsolete" "~@raw-io" "~@reboot" "~@resources" "~@swap" "~memfd_create" "~mincore" "~mlock" "~mlockall" "~personality" ];
      UMask = "0077";
    };
  };
}
