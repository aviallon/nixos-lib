{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
in {
  options.aviallon.desktop = {
    enable = mkOption {
      default = true;
      example = false;
      type = types.bool;
      description = "Enable desktop related configuration";
    };
    layout = mkOption {
      type = types.str;
      default = "fr";
      example = "us";
    };
  };

  config = mkIf cfg.enable {

    # Enable the X11 windowing system.
    services.xserver.enable = true;
    # Configure keymap in X11
    services.xserver.layout = cfg.layout;
    services.xserver.xkbOptions = "eurosign:e";


    # Enable the Plasma 5 Desktop Environment.
    services.xserver.displayManager.sddm.enable = true;
    services.xserver.desktopManager.plasma5.enable = true;

    # Enable CUPS to print documents.
    services.printing.enable = true;

    # Enable sound.
    sound.enable = true;
    # hardware.pulseaudio.enable = true;

    # Enable touchpad support (enabled default in most desktopManager).
    services.xserver.libinput.enable = true;


    environment.systemPackages = with pkgs; with libsForQt5; [
      firefox
      konsole
      kate
      yakuake
    ];

    networking.networkmanager = {
      packages = [
        pkgs.networkmanager-openvpn
      ];
    };
  };
}
