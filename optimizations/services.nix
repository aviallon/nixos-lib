{ config, options, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.optimizations;
  optimizePkg = cfg.optimizePkg;
  xorg = pkgs.xorg // {
    xorgserver = optimizePkg { } pkgs.xorg.xorgserver;
  };
  man-db = optimizePkg { level = "moderately-unsafe"; } pkgs.man-db;
  mandoc = optimizePkg { level = "moderately-unsafe"; } pkgs.mandoc;
in {
  config = mkIf cfg.enable {
    documentation.man.man-db.package = man-db;
    documentation.man.mandoc.package = mandoc;

    systemd.package = optimizePkg { } options.systemd.package.default;

    services.xserver.modules = mkBefore [ (hiPrio xorg.xorgserver.out) ];
    services.xserver.excludePackages = [ pkgs.xorg.xorgserver ];
    services.xserver.displayManager.xserverBin = mkForce "${xorg.xorgserver.out}/bin/X";

    environment.systemPackages = [
      (hiPrio config.systemd.package)
      (hiPrio xorg.xorgserver.out)
    ];
  };
}
