{ config, pkgs, lib, myLib, suyu, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  optimizePkg = config.aviallon.optimizations.optimizePkg;
  mkTmpDir = dirpath: cleanup: "D ${dirpath} 777 root root ${cleanup}";
in {

  options = {
    aviallon.desktop.gaming = {
      enable = mkEnableOption "gaming features";
      emulation = mkEnableOption "console emulators";
      yuzu.package = mkOption {
        type = with types; package;
        description = "Yuzu switch emulator package. WARNING: removed from nixpkgs";
        default = suyu.packages.${pkgs.system}.suyu;
      };
      ryujinx.package = mkOption {
        description = "Ryujinx Switch emulator package";
        type = myLib.types.package';
        default = pkgs.unstable.ryujinx;
        example = literalExpression "pkgs.unstable.ryujinx";
      };
    };
  };
  
  config = mkIf cfg.gaming.enable {
    assertions = [
      { assertion = cfg.gaming.enable -> cfg.enable; message = "Gaming features requires desktop to be enabled"; }
      { assertion = cfg.gaming.enable -> !generalCfg.minimal; message = "Gaming features are incompatible with minimal mode"; }
    ];
  
    environment.systemPackages = let
      my_yuzu = cfg.gaming.yuzu.package.overrideAttrs (old: {
        cmakeFlags = old.cmakeFlags ++ [
          #"-DYUZU_USE_PRECOMPILED_HEADERS=OFF"
          #"-DDYNARMIC_USE_PRECOMPILED_HEADERS=OFF"
        ];
      });
    in with pkgs; [
        gamescope
        mangohud
        lutris
        bottles
      ] ++ optionals cfg.gaming.emulation [
        (optimizePkg { recursive = 0; lto = false; } my_yuzu)
        (optimizePkg { } cfg.gaming.ryujinx.package)
      ];

    aviallon.windows.wine.enable = mkDefault true;

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

    users.groups.gamers = { };

    programs.steam.enable = !generalCfg.minimal;
    hardware.steam-hardware.enable = !generalCfg.minimal;
    programs.steam.remotePlay.openFirewall = true;
    programs.steam.localNetworkGameTransfers.openFirewall = true;
    environment.variables = {
      "__GL_SHADER_DISK_CACHE" = "true";
      "__GL_SHADER_DISK_CACHE_SIZE" = "${toString (50 * 1000)}";
      "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP" = "1"; # Avoid 128mb limit of shader cache
      "MESA_SHADER_CACHE_MAX_SIZE" = "50G"; # Put large-enough value. Default is only 1G
    };

    environment.sessionVariables = rec {
      XDG_CACHE_HOME = "$HOME/.cache";
      "__GL_SHADER_DISK_CACHE_PATH" = "${XDG_CACHE_HOME}/nvidia_gl";
      MESA_SHADER_CACHE_DIR = "${XDG_CACHE_HOME}/mesa";
      MESA_GLSL_CACHE_DIR = "${XDG_CACHE_HOME}/mesa";
    };

    hardware.graphics.extraPackages = [ pkgs.gamescope-wsi ];
    hardware.graphics.extraPackages32 = [ pkgs.pkgsi686Linux.gamescope-wsi ];

    programs.steam.package = pkgs.steam.override {
      extraPkgs = pkgs: [
        config.programs.gamescope.package
      ];
      #extraLibraries = pkgs: [
      #  config.programs.gamescope.package.override { enableExecutable = false; enableWsi = true; }
      #];
    };

    aviallon.programs.allowUnfreeList = [
      "steam" "steam-original" "steam-runtime" "steam-run"
    ];

  };
}
