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
      emulation = mkEnableOption "console emulators";
      yuzu.package = mkOption {
        description = "Yuzu switch emulator package";
        type = with types; package;
        example = pkgs.yuzu-early-access;
        default = pkgs.yuzu-mainline;
      };
    };
  };
  
  config = mkIf cfg.gaming.enable {
    assertions = [
      { assertion = cfg.gaming.enable -> cfg.enable; message = "Gaming features requires desktop to be enabled"; }
      { assertion = cfg.gaming.enable -> !generalCfg.minimal; message = "Gaming features are incompatible with minimal mode"; }
    ];
  
    environment.systemPackages = with pkgs; [
      #gamescope
      mangohud
      lutris
    ] ++ optionals cfg.gaming.emulation [
      cfg.gaming.yuzu.package
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
    security.wrappers = {
      my-gamemoderun = {
        source = "${pkgs.gamemode}/bin/gamemoderun";
        owner = "root";
        group = "gamers";
        capabilities = "cap_sys_nice=eip";
        permissions = "u+rx,g+x,o=";
      };
    };

    users.groups.gamers = { };

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

    programs.steam.package = pkgs.steam.override {
      extraPkgs = pkgs: [
        pkgs.gamescope
      ];
    };

    aviallon.programs.allowUnfreeList = [
      "steam" "steam-original" "steam-runtime" "steam-run"
    ];

    systemd.tmpfiles.rules = [
      (mkTmpDir (cfg.graphics.shaderCache.path + "/nvidia") cfg.graphics.shaderCache.cleanupInterval)
      (mkTmpDir (cfg.graphics.shaderCache.path + "/mesa") cfg.graphics.shaderCache.cleanupInterval)
    ];
  };
}
