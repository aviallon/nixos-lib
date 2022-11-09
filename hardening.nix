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
      description = "Enable hardcore hardening, which might break things. Forces expensive hardening.";
      type = types.bool;
    };

    expensive = mkOption {
      default = cfg.hardcore || !desktopCfg.enable;
      example = desktopCfg.enable;
      description = "Enable expensive hardening option (reduces performance)";
      type = types.bool;
    };

    services = {
      dbus = mkOption rec {
        default = cfg.hardcore;
        example = !default;
        description = "Enable dbus service hardening";
        type = types.bool;
      };
    };
  };

  config = mkIf cfg.enable {
  #  imports = [
  #     (modulesPath + "/profiles/hardened.nix")
  #  ];
    aviallon.boot.kernel = mkIf cfg.hardcore pkgs.linuxKernel.kernels.linux_hardened;
    security.lockKernelModules = mkIf cfg.hardcore (mkOverride 500 true);
    # security.protectKernelImage = mkIf cfg.hardcore (mkOverride 500 false); # needed for kexec

    aviallon.hardening.expensive = mkIf cfg.hardcore (mkForce true);

    services.openssh.permitRootLogin = "prohibit-password";

    security.apparmor.enable = true;
    services.dbus.apparmor = "enabled";

    aviallon.boot.cmdline = {
      "lsm" = [ "landlock" ]
        ++ optional cfg.hardcore "lockdown"
        # Apparmor https://wiki.archlinux.org/title/AppArmor#Installation
        ++ optionals config.security.apparmor.enable [ "apparmor" ]
        ++ [ "yama" ]
        ++ [ "bpf" ]
      ;
      "lockdown" = if cfg.hardcore then "confidentiality" else "integrity";

      # Vsyscall page not readable (default is "emulate". "none" might break statically-linked binaries.)
      vsyscall = mkIf cfg.hardcore "xonly";
    } // (ifEnable cfg.expensive {
      # Slab/slub sanity checks, redzoning, and poisoning
      "slub_debug" = "FZP";

      # Overwrite free'd memory
      "page_poison" = 1;

      # Enable page allocator randomization
      "page_alloc.shuffle" = 1;

      "nordrand" = "";
      "random.trust_cpu" = "off";
    });

    boot.kernel.sysctl = {
      # Almost free security. https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
      "kernel.yama.ptrace_scope" = mkOverride 999 1;

      # https://lwn.net/Articles/420403/
      "kernel.kptr_restrict" = mkOverride 999 2;

      # Can have dire impact on performance if BPF network filtering is used.
      "net.core.bpf_jit_enable" = mkIf cfg.expensive (mkOverride 999 false);

      # Can be used by developers. Should be disabled on regular desktops.
      # https://www.kernel.org/doc/html/latest/trace/ftrace.html
      "kernel.ftrace_enabled" = mkIf cfg.hardcore (mkOverride 999 false);
    };

    # Is used in podman containers, for instance
    security.allowUserNamespaces = mkDefault true;
#    boot.blacklistedKernelModules = mkForce [ ];

    # Only authorize admins to use nix in hardcore mode
    nix.allowedUsers = mkIf cfg.hardcore (mkForce [ "@wheel" ]);

    # Can really badly affect performance in some occasions.
    security.audit.enable = mkIf cfg.expensive true;
    security.auditd.enable = mkIf cfg.expensive true;

    security.audit.rules = concatLists [
      (optional cfg.expensive "-a exit,always -F arch=b64 -S execve")
    ];


    systemd.services.dbus.serviceConfig = mkIf cfg.services.dbus {
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
