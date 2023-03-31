{ config, pkgs, lib, ... }:
with lib;
let
  xcfg = config.services.xserver;
  generalCfg = config.aviallon.general;
in {
  config = {
    services.kmscon = {
      hwRender = mkDefault xcfg.enable;
      extraConfig = ""
        + optionalString ( ! isNull xcfg.layout )
          "xkb-layout=${xcfg.layout}"
        + optionalString ( ! isNull xcfg.xkbVariant )
          "xkb-variant=${xcfg.xkbVariant}"
        + optionalString ( ! isNull xcfg.xkbOptions )
          "xkb-options=${xcfg.xkbOptions}"
        + "font-dpi=${toString (xcfg.dpi or 96)}"
      ;
      enable = mkDefault (! generalCfg.minimal );
    };
  };
}

