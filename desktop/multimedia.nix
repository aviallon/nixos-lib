{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

  filterConfig = pkgs.callPackage ./pipewire/pipewire-noise-filter.conf.nix {
    noiseFilterStrength = cfg.audio.noise-filter.strength;
  };

  airplayConfig = pkgs.callPackage ./pipewire/pipewire-airplay.conf.nix {};

  # Multimedia Packages

  ffmpeg-full-unfree = let
    withUnfree = pkgs.unstable.ffmpeg-full.override {
      withUnfree = true;
      withTensorflow = false;
    };
  in withUnfree;
  
in {
  config = mkIf (cfg.enable && !generalCfg.minimal) {
    environment.systemPackages = with pkgs; [
      ffmpeg-full-unfree
      krita
      (pkgs.wrapOBS { plugins = with obs-studio-plugins; [
        obs-pipewire-audio-capture
      ]; })
      
      scribus
      yt-dlp
      jellyfin-media-player

      #jamesdsp # Audio post-processing
    ];

    nixpkgs.overlays = [(final: prev: {
      inherit ffmpeg-full-unfree;
    })];


    # Enable sound.
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      alsa.support32Bit = mkDefault true;
      wireplumber.enable = true;
    };

    hardware.bluetooth.enable = true;
    hardware.bluetooth.settings = {
      General = {
        Experimental = true;
        KernelExperimental = concatStringsSep "," [
          "6fbaf188-05e0-496a-9885-d6ddfdb4e03e" # BlueZ Experimental ISO socket
        ];
      };
      Policy = {
        ResumeDelay = 4;
      };
    };

    services.pipewire.extraConfig.pipewire = {
      "10-combined-outputs" = {
        "context.modules" = [
          {
            name = "libpipewire-module-combine-stream";
            args = {
              "combine.mode" = "sink";
              "node.name" = "combine_sink";
              "node.description" = "Sortie combinée";
              "combine.latency-compensate" = true;
              "combine.props" = {
                "audio.position" = [ "FL" "FR" ];
              };
              "stream.props" = {};
              "stream.rules" = [
                {
                  matches = [
                    # any of the items in matches needs to match, if one does,
                    # actions are emited.
                    {
                      # all keys must match the value. ! negates. ~ starts regex.
                      #node.name = "~alsa_input.*"
                      "media.class" = "Audio/Sink";
                    }
                  ];
                  actions.create-stream = {};
                }
              ];
            };
          }
        ];
      };
    };

    # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
    services.pipewire.wireplumber.extraConfig = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true; # Should be default now
        "bluez5.enable-msbc" = true; # Default
        "bluez5.enable-hw-volume" = true; # Default
        "bluez5.headset-roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };
    };

    
    security.rtkit.enable = true; # Real-time support for pipewire

    aviallon.programs.allowUnfreeList = [
      "ffmpeg-full" # Because of unfree codecs
    ];


    # Hardware-agnostic audio denoising
    systemd.user.services = let
      mkPipewireModule = {conf, description}: {
        unitConfig = {
          Slice = "session.slice";
        };
        serviceConfig = {
          ExecStart = [
            "${getBin config.services.pipewire.package}/bin/pipewire -c ${conf}"
          ];
          Type = "simple";
          Restart = "on-failure";
        };
        bindsTo = [ "pipewire.service" ];
        after = [ "pipewire.service" ];
        environment = {
          PIPEWIRE_DEBUG = "3";
        };
        wantedBy = [ "pipewire.service" ];
        inherit description;
      };
    in {
      pipewire-noise-filter = mkIf cfg.audio.noise-filter.enable (
        (mkPipewireModule { conf = filterConfig; description = "Pipewire Noise Filter"; }) //
        {
          enable = cfg.audio.noise-filter.strength > 0.0;
        }
      );
      pipewire-airplay-sink = mkIf cfg.audio.airplay.enable (
        mkPipewireModule { conf = airplayConfig; description = "Pipewire Airplay Sink"; }
      );
    };

  };
}
