{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.non-persistence;
  impermanenceSrc = builtins.fetchGit {
    url = "https://github.com/nix-community/impermanence.git";
    ref = "master";
    rev = "ff2240b04ffb9322241b9f6374305cbf6a98a285"; 
  };
  persistFolder = "/persist";
  impermanence = import "${impermanenceSrc}/nixos.nix";
  mkLink = dest: src: ''L+ "${dest}" - - - - ${src}'';
  mkDir = dest: ''d "${dest}" - - - -'';
  mkPersist = path: concatLists [
    (optional (dirOf path != path) (mkDir (dirOf path)))
    [ (mkLink path "${persistFolder}/${path}") ]
  ];
in
{
  imports = [
    impermanence
  ];

  options.aviallon.non-persistence = {
    enable = mkEnableOption "non-persitent root"; 
  };
  config = mkIf cfg.enable {
    assertions = [
      { assertion = hasAttr persistFolder config.fileSystems;
        message = "A ${persistFolder} partition is needed for non-persistence";
      }
      { assertion = hasAttr "/var/log" config.fileSystems;
        message = "A /var/log separate parition is needed to avoid missing early logs.";
      }
    ];

    environment.etc = {
      nixos.source = "${persistFolder}/etc/nixos";
      NIXOS.source = "${persistFolder}/etc/NIXOS";
      machine-id.source = "${persistFolder}/etc/machine-id";
    };

    systemd.tmpfiles.rules = mkAfter (traceValSeq (concatLists [
      (mkPersist "/etc/NetworkManager/system-connections")
    ]));


    fileSystems = {
      "/var/log" = {
        neededForBoot = true;
        autoFormat = true;
        label = "nixos-persistent-logs";
      };
      "${persistFolder}" = {
        neededForBoot = true;
        label = "nixos-persistent-data";
      };
    };
  };
}
