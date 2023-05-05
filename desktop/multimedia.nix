{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  filterConfig = pkgs.callPackage ./pipewire-noise-filter.cfg.nix {
    noiseFilterStrength = cfg.audio.noise-filter.strength;
  };
in {
  config = mkIf (cfg.enable && !generalCfg.minimal) {
    environment.systemPackages = with pkgs; [
      myFFmpeg
      krita
      obs-studio
      scribus
      yt-dlp
      jellyfin-media-player

      jamesdsp # Audio post-processing
    ];


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


    # Hardware-agnostic audio denoising
    systemd.user.services.pipewire-noise-filter = mkIf cfg.audio.noise-filter.enable {
      unitConfig = {
        Slice = "session.slice";
      };
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

  };
}
