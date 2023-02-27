{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  mkTmpDir = dirpath: cleanup: "D ${dirpath} 777 root root ${cleanup}";
in {

  options = {
    aviallon.desktop.gaming = {
      enable = mkEnableOption "gaming features";
    };
  };
  
  config = mkIf cfg.gaming.enable {
    assertions = [
      { assertion = cfg.gaming.enable -> cfg.enable; message = "Gaming features requires desktop to be enabled"; }
    ];
  
    environment.systemPackages = with pkgs; [
      #gamescope
      mangohud
      lutris
    ];

    boot.kernel.sysctl = {

      # Fixes crash in Hogwarts Legacy when using Floo network (https://steamcommunity.com/app/990080/discussions/0/3773490215223050912/)
      "vm.max_map_count" = 512 * 1024;
    };

    programs.gamemode = {
      settings = {
        general = {
          renice = 15;
          softrealtime = "auto";
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          amd_performance_level = "high";
          nv_powermizer_mode = 1;
        };
      };
      enable = true;
    };

    programs.steam.enable = !generalCfg.minimal;
    hardware.steam-hardware.enable = !generalCfg.minimal;
    programs.steam.remotePlay.openFirewall = true;
    environment.variables = {
      "__GL_SHADER_DISK_CACHE" = "true";
      "__GL_SHADER_DISK_CACHE_SIZE" = "${toString (50 * 1000)}";
      "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP" = "1"; # Avoid 128mb limit of shader cache
      "__GL_SHADER_DISK_CACHE_PATH" = cfg.graphics.shaderCache.path + "/nvidia" ;
      "MESA_SHADER_CACHE_MAX_SIZE" = "50G"; # Put large-enough value. Default is only 1G
      "MESA_SHADER_CACHE_DIR" = cfg.graphics.shaderCache.path + "/mesa";
      "MESA_GLSL_CACHE_DIR" = cfg.graphics.shaderCache.path + "/mesa";
    };

    systemd.tmpfiles.rules = [
      (mkTmpDir (cfg.graphics.shaderCache.path + "/nvidia") cfg.graphics.shaderCache.cleanupInterval)
      (mkTmpDir (cfg.graphics.shaderCache.path + "/mesa") cfg.graphics.shaderCache.cleanupInterval)
    ];
  };
}
