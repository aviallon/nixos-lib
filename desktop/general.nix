{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  filterConfig = pkgs.callPackage ./pipewire-noise-filter.cfg.nix {
    noiseFilterStrength = cfg.audio.noise-filter.strength;
  };
in {
  options.aviallon.desktop = {
    enable = mkOption {
      default = true;
      example = false;
      type = types.bool;
      description = "Enable desktop related configuration";
    };
    environment = mkOption {
      default = "plasma";
      example = "gnome";
      type = with types; enum [ "plasma" "gnome" ];
      description = "What Desktop Environment to use";
    };
    layout = mkOption {
      type = types.str;
      default = "fr";
      example = "us";
      description = "Default keyboard layout for X and console";
    };
    audio = {
      noise-filter.strength = mkOption {
        description = "Noise reduction strength (from 0 to 100)";
        type = types.float;
        default = 80.0;
        example = 0.0;
      };
      noise-filter.enable = mkOption {
        description = "Wether to enable noise filter at all";
        type = types.bool;
        default = true;
        example = false;
      };
    };
    graphics = {
      shaderCache = {
        path = mkOption {
          description = "Where to put shader cache (currently only for NVidia)";
          type = types.path;
          default = "/var/tmp/shadercache";
          example = "/tmp/shadercache";
        };
        cleanupInterval = mkOption {
          description = "Interval for cache cleanup (tmpfiles.d format). Set to '-' to disable.";
          type = types.str;
          default = "180d";
          example = "-";
        };
      };
    };
  };

  config = mkIf cfg.enable {

    aviallon.network.backend = mkDefault "NetworkManager";

    aviallon.boot.kernel = pkgs.linuxKernel.kernels.linux_xanmod;

    # Enable the X11 windowing system.
    services.xserver.enable = true;
    # services.xserver.tty = mkOverride 70 1;

    systemd.services."getty@tty1".enable = mkOverride 50 false;
    systemd.services."autovt@tty1".enable = mkOverride 50 false;

    # Configure keymap in X11
    services.xserver.layout = cfg.layout;
    services.xserver.xkbOptions = "eurosign:e";


    boot.plymouth.enable = mkDefault (!generalCfg.minimal);
    aviallon.boot.cmdline = {
      splash = mkIf (!generalCfg.debug) "";
      "udev.log_level" = mkIf (!generalCfg.debug) 3;
      preempt = "full";
      "usbhid.mousepoll" = 1; # 1ms latency for mouse
      "usbhid.kbpoll" = 4; # 4ms latency for kb
    };
    boot.initrd.verbose = generalCfg.debug;
    boot.consoleLogLevel = mkIf (!generalCfg.debug) 1;
    
    console.earlySetup = true; # Prettier console
    fonts.enableDefaultFonts = mkIf (!generalCfg.minimal) true;

    hardware.acpilight.enable = mkIf (!generalCfg.minimal) true;
    hardware.opentabletdriver.enable = mkIf (!generalCfg.minimal) true;

    hardware.bluetooth = mkIf (!generalCfg.minimal) {
      enable = true;
      package = pkgs.bluezFull;
    };

    security.polkit.enable = true; # Better interactive privilege prompts

    # Enable running X11 apps on Wayland
    programs.xwayland.enable = true;
    
    # Enable touchpad support (enabled default in most desktopManager).
    services.xserver.libinput.enable = true;

    hardware.opengl.driSupport = true;
    # For 32 bit applications
    hardware.opengl.driSupport32Bit = mkIf (!generalCfg.minimal) (mkDefault true);

    # programs.gnupg.agent.pinentryFlavor = "qt";

    environment.systemPackages = with pkgs; []
      ++ [
        p7zip
      ]
      ++ optionals (!generalCfg.minimal) [
        glxinfo
        vdpauinfo
        libva-utils
        spotify
        nextcloud-client
        libreoffice-fresh
        tdesktop
        vlc
        veracrypt
      ]
    ;


    aviallon.programs.allowUnfreeList = [
      "spotify" "spotify-unwrapped"

      "veracrypt"
    ];

    services.packagekit.enable = mkDefault (!generalCfg.minimal);
    security.sudo.extraConfig =
      ''
      # Keep X-related variables for better GUI integration
      Defaults:root,%wheel env_keep+=XAUTHORITY
      Defaults:root,%wheel env_keep+=DISPLAY
      ''
    ;
    
    networking.networkmanager = {
      plugins = []
        ++ optional (!generalCfg.minimal) pkgs.networkmanager-openvpn
      ;
    };
  };
}
