{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  desktopCfg = config.aviallon.desktop;
  cfg = config.aviallon.flatpak;

  inherit (config.services.flatpak) package;

  # ---------------------------------------------------------------------------
  # OS-managed app set -> /etc/flatpak/preinstall.d/<file>
  #
  # `flatpak preinstall` synchronises this list: it installs what is declared,
  # uninstalls refs that were preinstalled and are no longer declared, and
  # adopts already-installed apps as preinstalled on the first run (upstream
  # `flatpak_transaction_add_sync_preinstalled`, flatpak 1.18.1).
  # ---------------------------------------------------------------------------
  preinstallFile = pkgs.writeText "nixos-flatpak-preinstall" (
    concatStrings (
      map (p: ''
        [Flatpak Preinstall ${p.id}]
        Branch=${p.branch}
        IsRuntime=${boolToString p.runtime}
        ${optionalString (!p.install) "Install=false"}
        ${optionalString (p.collectionId != null) "CollectionID=${p.collectionId}"}
      '') cfg.packages
    )
  );

  # ---------------------------------------------------------------------------
  # Sandbox overrides -> /var/lib/flatpak/overrides/<id>
  # ---------------------------------------------------------------------------
  overrideIni = import ./flatpak-overrides.nix { inherit lib; };


  # Attrsets typed `attrsOf` do not merge with their `default`, so the built-in
  # `global` override is applied here instead of as an option default.
  globalOverride = cfg.overrides.global or { };
  effectiveOverrides = cfg.overrides // {
    global = globalOverride // {
      filesystems = [ "/usr/share/icons:ro" ] ++ (globalOverride.filesystems or [ ]);
    };
  };

in
{
  options.aviallon.flatpak = {
    enable = mkOption {
      type = types.bool;
      default = config.aviallon.desktop.enable;
      defaultText = literalExpression "config.aviallon.desktop.enable";
      description = "Declarative Flatpak application management.";
    };

    remotes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            url = mkOption {
              type = types.str;
              description = "URL of the `.flatpakrepo` file.";
            };
            hash = mkOption {
              type = types.str;
              description = ''
                SRI hash of the `.flatpakrepo` file. Required on purpose: the
                file carries the repository GPG key, so pinning it makes a key
                rotation a deliberate, reviewed bump (fail closed).
              '';
            };
          };
        }
      );
      default = {
        flathub = {
          url = "https://dl.flathub.org/repo/flathub.flatpakrepo";
          hash = "sha256-M3HdJQ5h2eFjNjAHP+/aFTzUQm9y9K+gwzc64uj+oDo=";
        };
      };
      description = ''
        Remotes declared as `*.flatpakrepo` files in `/etc/flatpak/remotes.d`.
        Flatpak applies them automatically the next time a command opens the
        *system* installation (`_flatpak_dir_ensure_repo`). A remote whose name
        already exists is never re-applied, so this is provisioning: a GPG key
        rotation needs `flatpak remote-delete --force <name>` followed by any
        flatpak command.
      '';
    };

    packages = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            id = mkOption {
              type = types.str;
              description = "Application or runtime id, e.g. `org.videolan.VLC`.";
            };
            branch = mkOption {
              type = types.str;
              default = "stable";
              description = "Flatpak branch.";
            };
            runtime = mkOption {
              type = types.bool;
              default = false;
              description = "Whether `id` is a runtime rather than an application.";
            };
            install = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether the ref should be installed. `false` keeps an installed
                ref from being uninstalled without installing it (the upstream
                `Install=false` key).
              '';
            };
            collectionId = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Restrict the ref to remotes carrying this collection id.";
            };
          };
        }
      );
      default = [ ];
      description = ''
        Applications/runtimes kept installed by the OS mechanism
        (`flatpak preinstall`, see `/etc/flatpak/preinstall.d`).

        Removing an entry here uninstalls it on the next sync (boot or
        `nixos-rebuild switch`), except for a user who has manually
        uninstalled it: upstream treats that as an opt-out and never
        reinstalls it.
      '';
    };

    overrides = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            shared = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "network" "ipc" ];
              description = "`[Context] shared=` entries.";
            };
            sockets = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "wayland" "x11" "pulseaudio" "pcsc" ];
              description = "`[Context] sockets=` entries.";
            };
            devices = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "dri" "all" ];
              description = "`[Context] devices=` entries.";
            };
            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "bluetooth" "devel" ];
              description = "`[Context] features=` entries.";
            };
            filesystems = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "xdg-download" "~/Games:ro" ];
              description = ''
                `[Context] filesystems=` entries. Only ever point at stable
                paths (`/run/current-system/sw/...`, `~`, `xdg-*`), never at a
                `/nix/store/...-<hash>` path: those get garbage collected and
                the entry silently dangles.
              '';
            };
            persistent = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "`[Context] persistent=` entries.";
            };
            environment = mkOption {
              type = types.attrsOf types.str;
              default = { };
              example = { MOZ_ENABLE_WAYLAND = "1"; };
              description = "`[Environment]` entries (set variables).";
            };
            unsetEnvironment = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "MESA_SHADER_CACHE_DIR" ];
              description = ''
                `[Context] unset-environment=` entries. This is the only way to
                *remove* a leaked host variable: an empty `[Environment] KEY=`
                merely sets it to the empty string.
              '';
            };
            sessionBus = mkOption {
              type = types.attrsOf (types.enum [ "talk" "see" "own" "none" ]);
              default = { };
              example = { "org.kde.plasma.browser.integration" = "talk"; };
              description = "`[Session Bus Policy]` entries.";
            };
            systemBus = mkOption {
              type = types.attrsOf (types.enum [ "talk" "see" "own" "none" ]);
              default = { };
              description = "`[System Bus Policy]` entries.";
            };
            extraContext = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Escape hatch: raw extra `[Context]` key/value pairs.";
            };
          };
        }
      );
      default = { };
      description = ''
        Per-app sandbox permissions, written to
        `/var/lib/flatpak/overrides/<id>` (`global` is just another key; a
        `global` entry always also grants read access to
        `/usr/share/icons`).

        The file is a symlink to the store (`L+`), so a manual
        `flatpak override --system` is reverted by the next
        `nixos-rebuild switch`. Effective order: system global -> system app
        -> user global -> user app, so a user override still wins.
      '';
    };

    autoUpdate = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run `flatpak update` from a systemd timer, decoupled from nixos-rebuild.";
      };
      interval = mkOption {
        type = types.str;
        default = "daily";
        example = "*-*-* 04:00:00";
        description = "systemd `OnCalendar` expression for the update timer.";
      };
      randomizedDelaySec = mkOption {
        type = types.str;
        default = "30min";
        description = "systemd `RandomizedDelaySec` for the update timer.";
      };
    };
  };

  config = mkIf (desktopCfg.enable && cfg.enable) {
    services.flatpak.enable = mkDefault true;

    # --- Remotes: applied automatically when a command opens the system
    #     installation. Replaces the old imperative `flatpak-add-flathub`.
    #     Also declares the app set (`flatpak preinstall`).
    environment.etc =
      (mapAttrs' (name: r: {
        name = "flatpak/remotes.d/${name}.flatpakrepo";
        value.source = pkgs.fetchurl { inherit (r) url hash; };
      }) cfg.remotes)
      // {
        "flatpak/preinstall.d/10-desktop-apps.preinstall".source = preinstallFile;
      };

    systemd.services.flatpak-preinstall = {
      description = "Synchronise OS-managed Flatpak applications";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Re-run on the next switch whenever the list changes, without a reboot.
      restartTriggers = [ preinstallFile ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Root bypasses the system helper entirely (no polkit prompt, no
        # logged-in session needed), which is why this is a system service.
        ExecStart = "${getExe' package "flatpak"} preinstall -y --noninteractive";
        # An offline first boot must not fail the boot; retry later.
        # `--reinstall` is deliberately NOT used: it would destroy user data,
        # and upstream's opt-out semantics (a user uninstalling an app opts out)
        # are what we want.
        Restart = "on-failure";
        RestartSec = "5min";
      };
    };

    # --- Application updates, independent of nixos-rebuild.
    systemd.services.flatpak-update = {
      description = "Update Flatpak applications";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${getExe' package "flatpak"} update -y --noninteractive";
      };
    };

    systemd.timers.flatpak-update = mkIf cfg.autoUpdate.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.autoUpdate.interval;
        Persistent = true;
        RandomizedDelaySec = cfg.autoUpdate.randomizedDelaySec;
      };
    };

    # --- Sandbox overrides. `L+` (not `C+`): tmpfiles' copy types never
    #     overwrite an existing file, while `L+` replaces even a regular file
    #     written by `flatpak override --system` with the store symlink.
    systemd.tmpfiles.settings."10-flatpak-overrides" = mapAttrs' (id: ctx: {
      name = "/var/lib/flatpak/overrides/${id}";
      value."L+".argument = toString (pkgs.writeText "flatpak-override-${id}" (overrideIni ctx));
    }) effectiveOverrides;

    # Make the nix icon theme available where the `global` override grants
    # access to it (NixOS does not populate /usr/share).
    fileSystems."/usr/share/icons" = {
      device = "/run/current-system/sw/share/icons";
      fsType = "none";
      options = [
        "rbind"
        "ro"
        "x-gvfs-hide"
      ];
    };
  };
}
