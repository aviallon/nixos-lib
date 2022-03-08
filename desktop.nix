{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  filterConfig = pkgs.writeText "pipewire-noise-filter.cfg"  ''
# Noise canceling source
#
# start with pipewire -c filter-chain/source-rnnoise.conf
#
context.properties = {
    log.level        = 0
}

context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}

context.modules = [
    {   name = libpipewire-module-rtkit
        args = {
            #nice.level   = -11
            #rt.prio      = 88
            #rt.time.soft = 200000
            #rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
    {   name = libpipewire-module-protocol-native }
    {   name = libpipewire-module-client-node }
    {   name = libpipewire-module-adapter }

    {   name = libpipewire-module-filter-chain
        args = {
            node.name =  "rnnoise_source"
            node.description =  "Noise Canceling source"
            media.name =  "Noise Canceling source"
            filter.graph = {
                nodes = [
                    {
                        type = ladspa
                        name = rnnoise
                        plugin = ${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so
                        label = noise_suppressor_stereo
                        control = {
                            "VAD Threshold (%)" ${toString cfg.audio.noise-filter.strength}
                        }
                    }
                ]
            }
            capture.props = {
                node.passive = true
            }
            playback.props = {
                media.class = Audio/Source
            }
        }
    }
]'';
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
      description = "Default keyboard layout for X and console";
    };
    audio = {
      noise-filter.strength = mkOption {
        description = "Noise reduction strength (from 0 to 100)";
        type = types.float;
        default = 80.0;
        example = 0.0;
      };
    };
  };

  config = mkIf cfg.enable {

    aviallon.network.backend = mkDefault "NetworkManager";

    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;

    # Enable the X11 windowing system.
    services.xserver.enable = true;
    # services.xserver.tty = mkOverride 70 1;

    systemd.services."getty@tty1".enable = mkOverride 50 false;
    systemd.services."autovt@tty1".enable = mkOverride 50 false;
    
    systemd.tmpfiles.rules = mkAfter (let
      sddmDir = "/var/lib/sddm";
    in [
      "e ${sddmDir}/.cache/sddm-greeter/qmlcache/ - - - 0"
      "x ${sddmDir}/.cache"

      # Fix SDDM cursor theme
      #"d ${sddmDir}/.config/xsettingsd 0755 sddm sddm -"
      #"f ${sddmDir}/.config/xsettingsd/xsettingsd.conf 0644 sddm sddm - Gtk/CursorThemeName \"breeze_cursors\""
      
      #"d ${sddmDir}/.config/gtk-4.0 0755 sddm sddm -"
      #"f ${sddmDir}/.config/gtk-4.0/settings.ini 0644 sddm sddm - gtk-cursor-theme-name=breeze_cursors"
      #"w+ ${sddmDir}/.config/gtk-4.0/settings.ini 0644 sddm sddm - gtk-cursor-theme-size=24"
    ]);

     # Prevents blinking cursor
    services.xserver.displayManager.sddm = {
      enable = true;
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
        };
        X11 = {
          MinimumVT = mkOverride 50 1;
        };
      };
    };

    # Configure keymap in X11
    services.xserver.layout = cfg.layout;
    services.xserver.xkbOptions = "eurosign:e";


    # Enable the Plasma 5 Desktop Environment.
    services.xserver.desktopManager.plasma5 = {
      enable = true;
      runUsingSystemd = true;
      useQtScaling = true;
      supportDDC = true;
    };

    boot.plymouth.enable = mkDefault true;
    boot.kernelParams = [ "quiet" "splash" "udev.log_level=3" ];
    boot.initrd.verbose = false;
    boot.consoleLogLevel = 1;

    # Enable sound.
    sound.enable = false;
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      alsa.support32Bit = mkDefault true;
      media-session.enable = true;
    };
    security.rtkit.enable = true; # Real-time support for pipewire


    # Hardware-agnostic audio denoising
    systemd.user.services.pipewire-noise-filter = {
      serviceConfig = {
        ExecStart = [
          "${pkgs.pipewire}/bin/pipewire -c ${filterConfig}"
        ];
        Type = "simple";
        Restart = "on-failure";
      };
      bindsTo = [ "pipewire.service" ];
      after = [ "pipewire.service" ];
      environment = {
        PIPEWIRE_DEBUG = "3";
      };
      enable = cfg.audio.noise-filter.strength > 0.0;
      wantedBy = [ "pipewire.service" ];
      description = "Pipewire Noise Filter";
    };

    # Enable touchpad support (enabled default in most desktopManager).
    services.xserver.libinput.enable = true;

    hardware.opengl.driSupport = true;
    # For 32 bit applications
    hardware.opengl.driSupport32Bit = true;

    programs.gnupg.agent.pinentryFlavor = "qt";

    environment.systemPackages = with pkgs; with libsForQt5; [
#      firefox
      konsole
      kate
      yakuake
      pinentry-qt
      plasma-pa
      ( ark.override {
        unfreeEnableUnrar = true;
      } )
      p7zip
      vlc
      skanlite
      packagekit-qt
      discover
    ];

    services.packagekit.enable = true;
    
    aviallon.programs.allowUnfreeList = [
      "unrar"
      "ark"
    ];

    networking.networkmanager = {
      packages = [
        pkgs.networkmanager-openvpn
      ];
    };
  };
}
