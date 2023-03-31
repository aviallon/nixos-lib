{config, pkgs, lib, utils, home-manager, ...}:
with lib;
let
  cfg = config.aviallon.home-manager;
  usersCfg = attrByPath [ "users" ] { users = {}; groups = {}; } config;
  defaultUsers = attrNames (filterAttrs (name: value: value.isNormalUser) usersCfg.users);
  hmUserCfg = u: config.home-manager.users.${u};
  userCfg = u: config.users.users.${u};
  getUserCfgPath = u: "${(userCfg u).home}/.config/nixpkgs/home.nix";

  homeManagerNixos = home-manager.nixosModules.home-manager {
    inherit config;
    inherit pkgs;
    inherit lib;
    inherit utils;
  };
in
{
  imports = [
    homeManagerNixos
  ];

  options.aviallon.home-manager = {
    enable = mkOption {
      default = true;
      example = false;
      description = "Global switch for home-manager config";
      type = types.bool;
    };
    users = mkOption {
      default = [ ];
      example = defaultUsers;
      description = "Users to add the default home-manager config to.";
      type = types.listOf types.str;
    };

    defaultHomeFile = mkOption {
      default = "/etc/nixos/homes/home.nix";
      example = literalExpression "/etc/skel/home.nix";
      description = "Default home.nix to place in .config/nixpkgs/home.nix when none exists";
      type = types.either types.path types.str;
    };
  };


  config = mkIf cfg.enable {
    home-manager.useUserPackages = true;
    home-manager.useGlobalPkgs = true;
    home-manager.backupFileExtension = "hmbackup";

    users.users = genAttrs cfg.users (u: {
      isNormalUser = true;
      group = "${u}";
      extraGroups = [ "audio" "video" "networkmanager" ];
    });
    users.groups = genAttrs cfg.users (u: { } );

    #environment.systemPackages = with pkgs; [
    #  home-manager
    #];

    home-manager.users = genAttrs cfg.users (u: {
      home.username = "${u}";
      home.homeDirectory = "${(userCfg u).home}";
      home.stateVersion = mkDefault config.system.stateVersion;

      programs.bash.enable = mkDefault true;
      qt.enable = mkDefault true;
      services.kdeconnect.enable = mkDefault true;
    });
  };
}
