{ config, pkgs, lib, myLib, ... }:
with lib;
let
  cfg = config.aviallon.nix;
  generalCfg = config.aviallon.general;
  desktopCfg = config.aviallon.desktop;
  buildUserPubKeyFile = ./id_builder.pub;
  buildUserKeyFile = ./id_builder;
  buildUserKeyFilePath = "/var/lib/nixos/aviallon.id_builder";

  getSpeed = cores: threads: cores + (threads - cores) / 2;

  mkBuildMachine = {
    hostName,
    cores,
    systems ? [ "x86_64-linux" ] ,
    threads ? (cores * 2),
    features ? [ ],
    x86ver ? 1 ,
    ...
  }@attrs: let
    speedFactor = getSpeed cores threads;
  in {
    inherit hostName speedFactor;
    systems = systems
      ++ optional (any (s: s == "x86_64-linux") systems) "i686-linux"
    ;
    sshUser = "builder";
    sshKey = buildUserKeyFilePath;
    maxJobs = myLib.math.log2 cores;
    supportedFeatures = [ "kvm" "benchmark" ]
      ++ optional (speedFactor > 8) "big-parallel"
      ++ optional (x86ver >= 2) "gccarch-x86-64-v2"
      ++ optional (x86ver >= 3) "gccarch-x86-64-v3"
      ++ optional (x86ver >= 4) "gccarch-x86-64-v4"
      ++ features
    ;
    
  };

  machineList = filterAttrs (name: value: config.networking.hostName != name && value.enable) cfg.builder.buildMachines;
in
{
  imports = [
    #(mkRenamedOptionModule [ "aviallon" "general" "flakes" "enable" ] [ "" ] "Flakes are now enabled by default")
  ];

  options.aviallon.nix.builder = {
    
    buildMachines = mkOption {
      type = types.attrsOf (types.submoduleWith {
        modules = [
        ({ config, options, name, ...}:
        {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Wether to enable or to disable this builder";
              example = false;
            };
            hostName = mkOption {
              type = types.str;
              example = "luke-skywalker-nixos";
              description = lib.mdDoc ''
                Builder's host name
              '';
            };
            sshConfig = mkOption {
              type = types.str;
              default = "";
              example = ''
                ProxyJump example.com
                Port 2222
              '';
              description = "Extra ssh config for the builder.";
            };
            cores = mkOption {
              type = with types; ints.unsigned;
              example = 8;
              description = "How many physical cores the builder has.";
            };
            threads = mkOption {
              type = with types; addCheck ints.unsigned (n: n >= config.cores);
              example = 16;
              description = lib.mdDoc "How many physical _threads_ the builder has.";
            };
            x86ver = mkOption {
              default = 1;
              type = with types; addCheck ints.positive (n: n >= 1 && n <= 4);
              example = 3;
              description = "Maximum x86-64 feature level supported.";
            };
          };

        })]; });
      default = {};
      example = literalExpression
        ''
          {
            luke-skywalker-nixos = {
              hostName = "2aXX:e0a:18e:8670::";
              cores = 16;
              threads = 32;
              x86ver = 3;
            };
          }
        '';
      description = "NixOS builders";
    };
  };

  config = {
    nix.buildMachines = traceValSeqN 3 (mapAttrsToList (name: value:
      mkBuildMachine {
        inherit (value) hostName cores threads x86ver;
      }
    ) machineList);

    programs.ssh.extraConfig = concatStringsSep "\n" (mapAttrsToList (name: value:
      (optionalString (value.sshConfig != "")
        ''
        Host ${value.hostName}
          ${value.sshConfig}
        ''
      )
    ) machineList);

    users.users.builder = {
      isSystemUser = true;
      group = "builder";
      password = mkForce null; # Must not have a password!
      openssh.authorizedKeys.keys = [
        (readFile buildUserPubKeyFile)
      ];
      shell = pkgs.bashInteractive;
    };
    users.groups.builder = {};
    nix.settings.trusted-users = [ "builder" ];

    boot.enableContainers = mkForce true;

    nix.distributedBuilds = mkDefault true;

    system.activationScripts = {
      buildUserKeySetup.text = ''
        cp --force -v ${buildUserKeyFile} ${buildUserKeyFilePath}
        chmod -c 400 ${buildUserKeyFilePath}
      '';
    };
  };

}
