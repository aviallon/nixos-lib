{ config, pkgs, lib, ... }:
with lib;
let
  hostGlCfg = config.aviallon.flatpak.hostGl;

  # The NixOS graphics driver aggregate — the store path /run/opengl-driver(32)
  # symlinks to. Rebuilt here with the same inputs, so same path.
  graphicsDrivers = pkgs.buildEnv {
    name = "graphics-drivers";
    paths = [ config.hardware.graphics.package ] ++ config.hardware.graphics.extraPackages;
  };

  graphicsDrivers32 = pkgs.buildEnv {
    name = "graphics-drivers-32bit";
    paths = [ config.hardware.graphics.package32 ] ++ config.hardware.graphics.extraPackages32;
  };

  mkTree = import ./flatpak-host-gl-tree.nix;

  tree64 = mkTree {
    inherit pkgs;
    name = "x86_64";
    drivers = graphicsDrivers;
    mountLib = "/usr/lib/x86_64-linux-gnu/GL/host/lib";
  };

  tree32 = mkTree {
    inherit pkgs;
    name = "i686";
    drivers = graphicsDrivers32;
    mountLib = "/usr/lib/i386-linux-gnu/GL/host/lib";
  };
in
{
  options.aviallon.flatpak.hostGl = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Install the host's GL driver stack as a flatpak GL extension
        (`org.freedesktop.Platform.GL.host` + `GL32.host`), built from
        `/run/opengl-driver{,-32}` and made self-contained by resolving the full
        library closure.

        A flatpak `*.host` extension is always active and, being unmanaged, has
        priority 1000 — it wins over the runtime's `GL.default`. Garbage in,
        every flatpak app broken. Enable per host, then verify.
      '';
    };
    branch = mkOption {
      type = types.str;
      default = "1.4";
      description = ''
        Extension branch. `1.4` is the branch declared by the GL extension
        point (`version = 1.4`) and is shared by every runtime branch.
      '';
    };
    enable32Bit = mkOption {
      type = types.bool;
      default = config.hardware.graphics.enable32Bit;
      defaultText = literalExpression "config.hardware.graphics.enable32Bit";
      description = "Also install the 32-bit extension (`org.freedesktop.Platform.GL32.host`).";
    };
  };

  config = mkIf (config.aviallon.flatpak.enable && hostGlCfg.enable) {
    systemd.tmpfiles.settings."10-flatpak-gl-host" = {
      "/var/lib/flatpak/extension/org.freedesktop.Platform.GL.host/x86_64/${hostGlCfg.branch}"."L+".argument =
        toString tree64;
    }
    // optionalAttrs hostGlCfg.enable32Bit {
      "/var/lib/flatpak/extension/org.freedesktop.Platform.GL32.host/i386/${hostGlCfg.branch}"."L+".argument =
        toString tree32;
    };
  };
}
