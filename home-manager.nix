{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.home-manager;
  usersCfg = config.users;
  defaultUsers = attrNames (filterAttrs (name: value: value.isNormalUser) usersCfg.users);
in
{
  imports = [
    <home-manager/nixos>
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

    systemd.tmpfiles.rules = concatLists (forEach cfg.users (u:
      [
        "d ${usersCfg.users.${u}.home}/.config/nixpkgs 0700 ${u} ${u} -"
        "C ${usersCfg.users.${u}.home}/.config/nixpkgs/home.nix 0600 ${u} ${u} - ${cfg.defaultHomeFile}"
      ]
    ));
  };
}
