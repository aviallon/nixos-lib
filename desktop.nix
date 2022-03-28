{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
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
    
    systemd.tmpfiles.rules = mkAfter [
      "e ${config.users.users.sddm.home}/.cache/sddm-greeter/qmlcache/ - - - 0"
      "x ${config.users.users.sddm.home}/.cache"
    ];

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
    boot.kernelParams = concatLists [
      (optionals (!generalCfg.debug) [ "splash" "udev.log_level=3" ])
      ["preempt=full"]
    ];
    boot.initrd.verbose = generalCfg.debug;
    boot.consoleLogLevel = mkIf (!generalCfg.debug) 1;

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

    xdg = {
      portal = {
        enable = true;
        gtkUsePortal = mkDefault true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
        ];
      };
    };

    # programs.gnupg.agent.pinentryFlavor = "qt";

    environment.systemPackages = with pkgs; with libsForQt5; [
#      firefox
      chromium
      konsole
      kate
      yakuake
      pinentry-qt
      plasma-pa
      ark
      p7zip
      vlc
      skanlite
      packagekit-qt
      discover
      akonadi
      kmail
      korganizer
      dolphin
      kio-fuse
      glxinfo
      vdpauinfo
      libva-utils
    ]
    ++ [
      spotify
      nextcloud-client
      libreoffice-fresh
      unstable.kotatogram-desktop
    ];

    programs.chromium = {
      enable = true;
      extensions = [
        "gcbommkclmclpchllfjekcdonpmejbdp;https://clients2.google.com/service/update2/crx" # HTTPS Everywhere
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" # Ublock Origin
      ];
      extraOpts = {
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = true;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "fr"
          "en-US"
        ];
        "DefaultSearchProviderEnabled" = true;
        "DefaultSearchProviderKeyword" = "duckduckgo";
        "DefaultSearchProviderName" = "DuckDuckGo";
        "ExtensionInstallSources" = [ 
          "https://chrome.google.com/webstore/*"
          "https://microsoftedge.microsoft.com/addons/*"
        ];
      };
      defaultSearchProviderSearchURL = ''https://duckduckgo.com/?kp=1&k1=-1&kav=1&kak=-1&kax=-1&kaq=-1&kap=-1&kau=-1&kao=-1&kae=d&q={searchTerms}'';
      defaultSearchProviderSuggestURL = ''https://ac.duckduckgo.com/ac/?q={searchTerms}'';
    };


    programs.steam.enable = true;
    hardware.steam-hardware.enable = true;
    programs.steam.remotePlay.openFirewall = true;


    aviallon.programs.allowUnfreeList = [
      "spotify"
      "spotify-unwrapped"

      "steam" "steam-original" "steam-runtime"
    ];

    services.packagekit.enable = true;
    
    networking.networkmanager = {
      packages = [
        pkgs.networkmanager-openvpn
      ];
    };
  };
}
