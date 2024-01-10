{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.programs;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  optimizeCfg = config.aviallon.optimizations;

  myOpenssh = if optimizeCfg.enable then (optimizeCfg.optimizePkg {} pkgs.openssh) else pkgs.openssh;
in
{
  imports = [
    ./programs
    (mkRenamedOptionModule [ "aviallon" "programs" "compileFlags" ] [ "aviallon" "optimizations" "extraCompileFlags" ])
  ];

  options.aviallon.programs = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Enable aviallon's programs";
      type = types.bool;
    };
    allowUnfreeList = mkOption {
      default = [ ];
      example = [ "nvidia-x11" "steam" ];
      description = "Allow specific unfree software to be installed";
      type = types.listOf types.str;
    };
    config = mkOption {
      default = {};
      type = types.attrs;
      example = { cudaSupport = true; };
      description = "nixpkgs config settings to be applied to all nixpkgs instances";
    };
  };

  config = mkIf cfg.enable {

    programs.java.enable = mkDefault (!generalCfg.minimal);

    aviallon.programs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.allowUnfreeList;

    environment.systemPackages = with pkgs; []
    ++ [
      vim
      wget
      nano
      myOpenssh
      psmisc
      pciutils
      ripgrep
      fd
      htop
      cachix
      usbutils
    ]
    ++ optionals (!generalCfg.minimal) [
      rsync
      par2cmdline # .par2 archive verification
      python3
      parallel
      coreutils-full
      nmap
      pv
      xxHash
      unzip
    ];

    programs.ssh.package = myOpenssh;

    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 9999;
      newSession = true;
    };

    programs.ccache.enable = true;
    
    nix.settings.extra-sandbox-paths = [
      (toString config.programs.ccache.cacheDir)
    ];

  };
}
