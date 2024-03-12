{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.security.encryption;
in {
  options.aviallon.security.encryption = {
    enable = mkEnableOption "encryption-related tools and programs";
    cryptsetup.package = mkOption {
      description = "Which cryptsetup package to use";
      type = types.path;
      default = pkgs.cryptsetup;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cfg.cryptsetup.package
    ];

    boot.initrd.systemd.contents."/etc/crypttab".text = mkDefault "";

    environment.etc.crypttab = {
      text = config.boot.initrd.systemd.contents."/etc/crypttab".text;
    };

    boot.initrd.systemd.enable = mkOverride 10 true;
    
    boot.initrd.availableKernelModules = [ "cryptd" ];
    boot.initrd.kernelModules = [ "jitterentropy_rng" ];
  };
}
