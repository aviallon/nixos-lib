{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
in {
  options.aviallon.hardware.nvidia.nouveau = {
    config = mkOption {
      description = "nouveau boot config";
      type = with types; attrsOf (nullOr (oneOf [ int str bool ]));
      example = { NvBoost = 1; };
      default = {};
    };
  };
  
  config = mkIf (cfg.enable && cfg.variant == "nouveau") {
    boot.initrd.kernelModules = [ "nouveau" ];

    aviallon.boot.cmdline = {
      "nouveau.pstate" = 1;
      "nouveau.runpm" = 1;
      "nouveau.modeset" = 1;
      "nouveau.config" = let
        toValue = v:
          if isBool v
            then toString (if v then 1 else 0)
          else toString v;
        filteredConfig = filterAttrs (n: v: ! isNull v) cfg.nouveau.config;
        configList = mapAttrsToList (n: v: "${n}=${toValue v}") filteredConfig;
        configString = concatStringsSep "," configList;
      in trace "Nouveau config: ${configString}" configString;
    };

    aviallon.hardware.mesa.enable = mkDefault true;

    aviallon.hardware.nvidia.nouveau.config.NvBoost = ifEnable (!config.aviallon.laptop.enable) true;

    environment.variables = {
      RUSTICL_ENABLE = "nouveau";
    };
  };
}
