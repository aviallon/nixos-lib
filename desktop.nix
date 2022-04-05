{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  filterConfig = pkgs.callPackage ./packages/pipewire-noise-filter.cfg.nix {
    noiseFilterStrength = cfg.audio.noise-filter.strength;
  };
  mkTmpDir = dirpath: cleanup: "D ${dirpath} 777 root root ${cleanup}";
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
    ./desktop/plasma.nix
  ];

  config = mkIf cfg.enable {

    aviallon.network.backend = mkDefault "NetworkManager";

    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;

    # Enable the X11 windowing system.
    services.xserver.enable = true;
    # services.xserver.tty = mkOverride 70 1;

    systemd.services."getty@tty1".enable = mkOverride 50 false;
    systemd.services."autovt@tty1".enable = mkOverride 50 false;

    # Configure keymap in X11
    services.xserver.layout = cfg.layout;
    services.xserver.xkbOptions = "eurosign:e";


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

    # programs.gnupg.agent.pinentryFlavor = "qt";

    environment.systemPackages = with pkgs; [
      myFirefox
      chromium
      p7zip
      vlc
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
    environment.variables = {
      "__GL_SHADER_DISK_CACHE" = "true";
      "__GL_SHADER_DISK_CACHE_SIZE" = "${toString (50 * 1000)}";
      "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP" = "1"; # Avoid 128mb limit of shader cache
      "__GL_SHADER_DISK_CACHE_PATH" = cfg.graphics.shaderCache.path + "/nvidia" ;
      "MESA_SHADER_CACHE_MAX_SIZE" = "50G"; # Put large-enough value. Default is only 1G
      "MESA_SHADER_CACHE_DIR" = cfg.graphics.shaderCache.path + "/mesa";
    };
    
    systemd.tmpfiles.rules = [
      (mkTmpDir (cfg.graphics.shaderCache.path + "/nvidia") cfg.graphics.shaderCache.cleanupInterval)
      (mkTmpDir (cfg.graphics.shaderCache.path + "/mesa") cfg.graphics.shaderCache.cleanupInterval)
    ];

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
