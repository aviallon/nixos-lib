{ config, pkgs, lib, myLib, opentabletdriver, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
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
      type = with types; enum [ "plasma" "plasma6" "gnome" ];
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
      airplay.enable = mkEnableOption "AirPlay sink device support";
    };
    graphics = {
      shaderCache = {
        cleanupInterval = mkOption {
          description = "Interval for cache cleanup (tmpfiles.d format). Set to '-' to disable.";
          type = types.str;
          default = "180d";
          example = "-";
        };
      };
    };
  };

  imports = [
    (mkRemovedOptionModule [ "aviallon" "desktop" "graphics" "shaderCache" "path" ] "Now always relative to $XDG_CACHE_HOME" )
  ];

  config = mkIf cfg.enable (mkMerge [
    {
      aviallon.network.backend = mkDefault "NetworkManager";

      aviallon.boot.kernel.package = mkDefault pkgs.linuxKernel.kernels.linux_xanmod;

      # Enable the X11 windowing system.
      # services.xserver.enable = true;
      # services.xserver.tty = mkOverride 70 1;

      systemd.services."getty@tty1".enable = mkOverride 50 false;
      systemd.services."autovt@tty1".enable = mkOverride 50 false;

      # Configure keymap in X11
      services.xserver.xkb.layout = cfg.layout;
      services.xserver.xkb.options = "eurosign:e";


      aviallon.boot.cmdline = {
        splash = mkIf (!generalCfg.debug) "";
        "udev.log_level" = mkIf (!generalCfg.debug) 3;
        preempt = mkDefault "full";
        "usbhid.mousepoll" = 1; # 1ms latency for mouse
        "usbhid.kbpoll" = 4; # 4ms latency for kb
        "systemd.log_level" = config.boot.initrd.systemd.managerEnvironment.SYSTEMD_LOG_LEVEL;

        sysrq_always_enabled = mkIf generalCfg.debug "";
      };
      boot.initrd.verbose = generalCfg.debug;
      boot.consoleLogLevel = mkIf (!generalCfg.debug) 1;
      boot.initrd.systemd.managerEnvironment = {
        SYSTEMD_LOG_LEVEL = if generalCfg.debug then toString config.boot.consoleLogLevel else "crit";
      };

      #console.enable = mkDefault false; # Completly disable console by default
      security.polkit.enable = true; # Better interactive privilege prompts

      # Enable running X11 apps on Wayland
      programs.xwayland.enable = true;
      
      # Enable touchpad support (enabled default in most desktopManager).
      services.libinput.enable = true;

      # Enable color management
      services.colord.enable = true;

      environment.systemPackages = with pkgs; [
        p7zip
      ];


      security.sudo.extraConfig =
        ''
        # Keep X and Wayland related variables for better GUI integration
        Defaults:root,%wheel env_keep+=DISPLAY
        Defaults:root,%wheel env_keep+=XAUTHORITY

        Defaults:root,%wheel env_keep+=WAYLAND_DISPLAY
        Defaults:root,%wheel env_keep+=WAYLAND_SOCKET
        Defaults:root,%wheel env_keep+=XDG_RUNTIME_DIR
        ''
      ;

    }
    (mkIf (!generalCfg.minimal) {
      boot.plymouth.enable = mkDefault true;

      fonts.enableDefaultPackages = true;
      fonts.fontconfig.useEmbeddedBitmaps = true; # Fixes Emojis not showing in Firefox

      hardware.acpilight.enable = true;
      hardware.opentabletdriver.enable = true;
      #hardware.opentabletdriver.package = opentabletdriver.packages.${pkgs.system}.opentabletdriver;

      hardware.bluetooth = {
        enable = true;
        # package = pkgs.bluez;
      };

      programs.thunderbird.enable = true;

      hardware.graphics.enable32Bit = mkDefault cfg.gaming.enable;
    
      environment.systemPackages = with pkgs; [
        mesa-demos
        vdpauinfo
        libva-utils
        spotify
        nextcloud-client
        unstable.telegram-desktop
        signal-desktop
        vlc
        veracrypt

        # Clipboard support on Wayland
        wl-clipboard

        # Spell check support
        hunspell
        hunspellDicts.fr-any

        aspell
        aspellDicts.fr
      ];

      environment.variables = {
        SDL_VIDEODRIVER = "wayland,x11";
        SDL_AUDIODRIVER = "pipewire,pulseaudio";

        QT_QPA_PLATFORM = "wayland;xcb";
        MOZ_DBUS_REMOTE = "1"; # For shared clipboard with Xwayland apps
        _JAVA_AWT_WM_NONREPARENTING = "1";

        # https://wiki.archlinux.org/title/Wayland#Environment_variable
        ELECTRON_OZONE_PLATFORM_HINT = "auto";

        # https://wiki.archlinux.org/title/Wayland#Java
        JAVA_TOOL_OPTIONS = "-Dawt.toolkit.name=WLToolkit";
      };

      aviallon.programs.allowUnfreeList = [
        "spotify" "spotify-unwrapped"

        "veracrypt"
      ];

    
      aviallon.programs.libreoffice.enable = true;
    
      services.packagekit.enable = mkDefault true;
    
      # SmartCards
      #services.pcscd.enable = mkDefault true;

      networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

      nixpkgs.overlays = [(final: prev: {

        # Patch rtkit to enable graceful systemd suspend support
        rtkit = myLib.optimizations.addAttrs prev.rtkit {
          patches = [
            (final.fetchpatch {
              name = "add-graceful-system-suspend-support.patch";
              url = "https://patch-diff.githubusercontent.com/raw/heftig/rtkit/pull/35.patch";
              hash = "sha256-NRVNSa7fzgEDn6ic/Vb36VCj2kv9AC6+Dm2uYNgbEZw=";
            })
          ];
        };
      })];
    })
  ]);
}
