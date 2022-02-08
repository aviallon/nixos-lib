{ config, pkgs, lib, ... }:
with lib;
let
  customKernelPatches = {
    enableX32ABI = {
      name = "enable-x32";
      patch = null;
      extraConfig = ''
        X86_X32 y
      '';
    };
    grayskyUarches = {
        name = "graysky-optimized-5.10";
        patch = pkgs.fetchpatch {
          name = "graysky-optimized-5.10.patch";
          url = "https://raw.githubusercontent.com/graysky2/kernel_compiler_patch/master/more-uarches-for-kernel-5.8-5.14.patch";
          #url = "https://raw.githubusercontent.com/graysky2/kernel_compiler_patch/master/more-uarches-for-kernel-5.15%2B.patch"
          sha256 = "sha256:079f1gvgj7k1irj25k6bc1dgnihhmxvcwqwbgmvrdn14f7kh8qb3";
        };
        extraConfig = ''
          MK10 y
        '';
      };
  };
  cfg = config.aviallon.boot;
  generalCfg = config.aviallon.general;
  allowUnfree = (types.isType types.attrs config.nixpkgs.config)
                && (hasAttr "allowUnfree" config.nixpkgs.config)
                && (getAttr "allowUnfree" config.nixpkgs.config);
in
{

  options.aviallon.boot = {
    enable = mkOption {
      description = "Enable default boot settings";
      default = true;
      example = false;
      type = lib.types.bool;
    };
    useGrub = mkOption {
      description = "Use Grub instead of systemd-boot";
      default = !cfg.efi;
      example = cfg.efi;
      type = types.bool;
    };
    x32abi = {
      enable = mkEnableOption "X32 kernel ABI";
    };
    efi = mkOption rec {
      description = "Use EFI bootloader";
      default = builtins.pathExists "/sys/firmware/efi";
      example = !default;
      type = types.bool;
    };
    configurationLimit = mkOption {
      description = "Maximum number of generations in the boot menu";
      default = 30;
      example = null;
      type = types.int;
    };
  };

  config = mkIf cfg.enable {

    hardware.enableAllFirmware = allowUnfree;
    hardware.enableRedistributableFirmware = true;

    boot = {
      initrd.kernelModules = [ ];
      initrd.availableKernelModules = [ "ehci_pci" ];

      kernelParams = concatLists [
        (optional cfg.x32abi.enable "syscall.x32=y")
      ];

      kernelPatches = concatLists [
        (optional cfg.x32abi.enable customKernelPatches.enableX32ABI)
      ];

      loader.grub.enable = cfg.useGrub || (!cfg.efi);
      loader.grub = {
        version = 2;
        device = (if cfg.efi then "nodev" else null);
        efiSupport = cfg.efi;
        configurationLimit = cfg.configurationLimit;
      };

      loader.systemd-boot = {
        enable = cfg.efi && (!cfg.useGrub);
        configurationLimit = cfg.configurationLimit; 
      };

      loader.generic-extlinux-compatible = {
        configurationLimit = cfg.configurationLimit;
      };

      loader = {
        efi.efiSysMountPoint = mkDefault "/boot/efi";
        efi.canTouchEfiVariables = mkDefault true;
      };
    };
  };
}
