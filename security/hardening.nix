{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardening;
  desktopCfg = config.aviallon.desktop;
  mkQuasiForce = x: lib.mkOverride 2 x;
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
    aviallon.boot.kernel.package = mkIf cfg.hardcore pkgs.linuxKernel.kernels.linux_hardened;
    security.lockKernelModules = mkIf cfg.hardcore (mkQuasiForce true);
    # security.protectKernelImage = mkIf cfg.hardcore (mkOverride 500 false); # needed for kexec

    aviallon.hardening.expensive = mkIf cfg.hardcore (mkQuasiForce true);

    security.sudo.execWheelOnly = true;

    services.openssh.settings.PermitRootLogin = "prohibit-password";

    security.apparmor.enable = true;
    services.dbus.apparmor = "enabled";

    aviallon.boot.cmdline = {
      "lsm" = [ "landlock" ]
        ++ optional cfg.hardcore "lockdown"
        ++ [ "yama" ]
        # Apparmor https://wiki.archlinux.org/title/AppArmor#Installation
        ++ optionals config.security.apparmor.enable [ "apparmor" ]
        ++ [ "bpf" ]
      ;
      "lockdown" = if cfg.hardcore then "confidentiality" else "integrity";

      # Vsyscall page not readable (default is "emulate". "none" might break statically-linked binaries.)
      vsyscall = mkIf cfg.hardcore "xonly";
    } // (ifEnable cfg.expensive {
      # Slab/slub sanity checks, redzoning, and poisoning
      "init_on_alloc" = 1;
      "init_on_free" = 1;

      # Overwrite free'd memory
      "page_poison" = 1;

      # Enable page allocator randomization
      "page_alloc.shuffle" = 1;

      "nordrand" = "";
      "random.trust_cpu" = "off";
    });

    boot.kernel.sysctl = {
      # Almost free security. https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
      "kernel.yama.ptrace_scope" = mkQuasiForce 1;

      # https://lwn.net/Articles/420403/
      "kernel.kptr_restrict" = mkQuasiForce 2;

      # Can be used by developers. Should be disabled on regular desktops.
      # https://www.kernel.org/doc/html/latest/trace/ftrace.html
      "kernel.ftrace_enabled" = mkIf cfg.hardcore (mkQuasiForce false);
    };

    # Is used in podman containers, for instance
    security.allowUserNamespaces = mkDefault true;
#    boot.blacklistedKernelModules = mkForce [ ];

    # Only authorize admins to use nix in hardcore mode
    nix.allowedUsers = mkIf cfg.hardcore (mkQuasiForce [ "@wheel" ]);

    # Can really badly affect performance in some occasions.
    security.audit.enable = mkDefault true;
    security.auditd.enable = mkQuasiForce false;

    security.audit.rules = concatLists [
      (optional cfg.expensive "-a exit,always -F arch=b64 -S execve")
    ];

    environment.systemPackages = with pkgs; [
      sbctl # Secure Boot keys generation
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
