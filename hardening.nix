{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardening;
  desktopCfg = config.aviallon.desktop;
in
{
  options.aviallon.hardening = {
    enable = mkOption {
      default = !desktopCfg.enable; # It usually conflicts with desktop use.
      example = desktopCfg.enable;
      description = "Enable aviallon's hardening";
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
  #  imports = [
  #     (modulesPath + "/profiles/hardened.nix")
  #  ];
    boot.kernelPackages = pkgs.linuxPackages_hardened;
    security.lockKernelModules = mkOverride 500 true;
    security.protectKernelImage = mkOverride 500 false; # needed for kexec

    security.apparmor.enable = true;
    services.dbus.apparmor = "enabled";

    boot.kernelParams = [
      # Slab/slub sanity checks, redzoning, and poisoning
      "slub_debug=FZP"

      # Overwrite free'd memory
      "page_poison=1"

      # Enable page allocator randomization
      "page_alloc.shuffle=1"
    ];

    boot.kernel.sysctl = {
    "kernel.yama.ptrace_scope" = lib.mkOverride 500 1;
    "kernel.kptr_restrict" = lib.mkOverride 500 2;

    "net.core.bpf_jit_enable" = lib.mkOverride 500 false;

    "kernel.ftrace_enabled" = lib.mkOverride 500 false;
    };

    security.allowUserNamespaces = mkDefault true;
    boot.blacklistedKernelModules = mkForce [ ];

    nix.allowedUsers = [ "@wheel" ];

    security.audit.enable = true;
    security.auditd.enable = true;

    security.audit.rules = [
      "-a exit,always -F arch=b64 -S execve"
    ];
  #  systemd.services.udisks2.confinement.enable = true;
  };
}
