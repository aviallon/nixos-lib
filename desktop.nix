{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  filterConfig = pkgs.callPackage ./packages/pipewire-noise-filter.cfg.nix {
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

  imports = [
    ./desktop
  ];

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
      reboot = mkDefault "warm";
      "usbhid.mousepoll" = 1; # 1ms latency for mouse
      "usbhid.kbpoll" = 4; # 4ms latency for kb
      "intel_pstate" = "passive";
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


    # Enable sound.
    sound.enable = false;
    services.pipewire = mkIf (!generalCfg.minimal) {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      alsa.support32Bit = mkDefault true;
      wireplumber.enable = true;
      config.pipewire-pulse = {
        "context.exec" = [
          { path = "pactl"; args = ''load-module module-combine-sink sink_name="Sorties combinées"''; }
        ];
      };
    };
    environment.etc = {
    	"wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
    		bluez_monitor.properties = {
    			["bluez5.enable-sbc-xq"] = true,
    			["bluez5.enable-msbc"] = true,
    			["bluez5.enable-hw-volume"] = true,
    			["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
    		}
    	'';
    };
    security.rtkit.enable = true; # Real-time support for pipewire

    security.polkit.enable = true; # Better interactive privilege prompts

    # Enable running X11 apps on Wayland
    programs.xwayland.enable = true;

    # Hardware-agnostic audio denoising
    systemd.user.services.pipewire-noise-filter = mkIf cfg.audio.noise-filter.enable {
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
    hardware.opengl.driSupport32Bit = mkIf (!generalCfg.minimal) (mkDefault true);

    # programs.gnupg.agent.pinentryFlavor = "qt";

    environment.systemPackages = with pkgs; [
      chromium
      p7zip
    ]
    ++ (optionals (!generalCfg.minimal) [
      glxinfo
      vdpauinfo
      libva-utils
      myFirefox
      spotify
      nextcloud-client
      libreoffice-fresh
      unstable.kotatogram-desktop
      vlc
    ]);

    programs.chromium = {
      enable = true;
      # https://docs.microsoft.com/en-us/microsoft-edge/extensions-chromium/enterprise/auto-update
      # https://clients2.google.com/service/update2/crx?x=id%3D{extension_id}%26v%3D{extension_version}
      extensions = [
        # "gcbommkclmclpchllfjekcdonpmejbdp;https://clients2.google.com/service/update2/crx" # HTTPS Everywhere
        "mleijjdpceldbelpnpkddofmcmcaknm" # Smart HTTPS
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" # Ublock Origin
        "fihnjjcciajhdojfnbdddfaoknhalnja" # I don't care about cookies
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
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
          "https://gitlab.com/magnolia1234/bypass-paywalls-chrome-clean/*"
        ];
        "BuiltInDnsClientEnabled" = false;
        "TranslateEnabled" = false;
        "PasswordLeakDetectionEnabled" = false;
        "CloudPrintProxyEnabled" = false;
        "CloudPrintSubmitEnabled" = false;
        "SafeBrowsingProtectionLevel" = 0; # Force disabled
      };
      defaultSearchProviderSearchURL = ''https://duckduckgo.com/?kp=1&k1=-1&kav=1&kak=-1&kax=-1&kaq=-1&kap=-1&kau=-1&kao=-1&kae=d&q={searchTerms}'';
      defaultSearchProviderSuggestURL = ''https://ac.duckduckgo.com/ac/?q={searchTerms}'';
    };


    aviallon.programs.allowUnfreeList = [
      "spotify"
      "spotify-unwrapped"

      "steam" "steam-original" "steam-runtime" "steam-run"
    ];

    services.packagekit.enable = mkDefault (!generalCfg.minimal);
    
    networking.networkmanager = {
      plugins = []
        ++ optional (!generalCfg.minimal) pkgs.networkmanager-openvpn
      ;
    };
  };
}
