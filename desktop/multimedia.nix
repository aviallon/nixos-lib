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

  myFFmpeg = let
    withUnfree = pkgs.unstable.ffmpeg-full.override {
      withUnfree = true;
      withTensorflow = !pkgs.unstable.libtensorflow.meta.broken;
    };
  in withUnfree;

  
  myFFmpeg_opt = config.aviallon.optimizations.optimizePkg { lto = false; } myFFmpeg;

  
  #ffmpeg_4 = config.aviallon.optimizations.optimizePkg { } pkgs.ffmpeg_4;
  #obs-studio = pkgs.obs-studio.override { inherit ffmpeg_4; };
  #myWrapOBS = pkgs.wrapOBS.override { inherit obs-studio; };
  myWrapOBS = pkgs.wrapOBS;
in {
  config = mkIf (cfg.enable && !generalCfg.minimal) {
    environment.systemPackages = with pkgs; [
      myFFmpeg_opt
      krita
      (myWrapOBS { plugins = with obs-studio-plugins; [
        obs-pipewire-audio-capture
      ]; })
      
      scribus
      yt-dlp
      jellyfin-media-player

      jamesdsp # Audio post-processing
    ];

    nixpkgs.overlays = [(final: prev: {
      myFFmpeg = myFFmpeg_opt;
    })];


    # Enable sound.
    sound.enable = mkOverride 40 false;
    hardware.pulseaudio.enable = mkOverride 40 false;
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      alsa.support32Bit = mkDefault true;
      wireplumber.enable = true;
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
      "pipewire/pipewire.conf.d/combined-outputs.conf".text = ''
        context.modules = [
        {   name = libpipewire-module-combine-stream
            args = {
                combine.mode = sink
                node.name = "combine_sink"
                node.description = "Sortie combinée"
                combine.latency-compensate = true
                combine.props = {
                    audio.position = [ FL FR ]
                }
                stream.props = {
                }
                stream.rules = [
                    {
                        matches = [
                            # any of the items in matches needs to match, if one does,
                            # actions are emited.
                            {
                                # all keys must match the value. ! negates. ~ starts regex.
                                #node.name = "~alsa_input.*"
                                media.class = "Audio/Sink"
                            }
                        ]
                        actions = {
                            create-stream = {
                                #combine.audio.position = [ FL FR ]
                                #audio.position = [ FL FR ]
                            }
                        }
                    }
                ]
            }
        }
        ]
        '';

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
            "${pkgs.pipewire}/bin/pipewire -c ${conf}"
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
