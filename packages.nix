{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.programs;
  desktopCfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;

in
{
  imports = [
    ./programs
    ./overlays.nix
    ./packages/unstable.nix
    ./packages/flatpak.nix
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
  };

  config = mkIf cfg.enable {

    programs.java.enable = mkDefault (!generalCfg.minimal);

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) cfg.allowUnfreeList;

    environment.systemPackages = with pkgs; with libsForQt5; []
    ++ [
      vim
      wget
      nano
      openssh
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
    ]
    ++ (optionals config.aviallon.developer.enable [
      schedtool
      clinfo
      binutils
      cpuset
      gptfdisk # gdisk
    
      gcc
      gnumake
      cmake
    ])
    ;

    programs.ssh.package = pkgs.opensshOptimized;

    programs.tmux = {
      enable = true;
      clock24 = true;
      historyLimit = 9999;
      newSession = true;
    };

    aviallon.programs.allowUnfreeList = [
    ];

    programs.ccache.enable = true;
    
    nix.settings.extra-sandbox-paths = [
      (toString config.programs.ccache.cacheDir)
    ];

  };
}
