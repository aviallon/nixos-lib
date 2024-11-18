{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
in {
  config = mkIf (cfg.enable && !generalCfg.minimal) {
    services.printing = {
      enable = true;
      defaultShared = mkDefault true;
      browsing = mkDefault true;
      listenAddresses = [ "0.0.0.0:631" ];
      drivers = with pkgs; []
        ++ (optionals (!generalCfg.minimal) [
        hplipWithPlugin
        gutenprint
        splix
        brlaser
        cups-bjnp  
        # cups-dymo
        # cups-zj-58
        # cups-kyocera
        cups-filters  
        carps-cups  
        # cups-kyodialog3
        cups-brother-hl1110
        cups-toshiba-estudio
        cups-brother-hl1210w
        cups-brother-hl3140cw
        cups-brother-hll2340dw
        cups-drv-rastertosag-gdi
        # cups-kyocera-ecosys-m552x-p502x
        canon-cups-ufr2
      ]);
      webInterface = mkDefault true;
    };
    services.system-config-printer.enable = true;

    hardware.sane = {
      enable = true;
      netConf = "192.168.0.0/24";  
      extraBackends = with pkgs; [
        hplipWithPlugin
      ];
      brscan5.enable = true;
      brscan4.enable = true;
    };

    networking.firewall.allowedTCPPorts = optionals config.services.printing.enable [ 631 139 445 ];
    networking.firewall.allowedUDPPorts = optionals config.services.printing.enable [ 137 ]; 


    aviallon.programs.allowUnfreeList = [
      "hplip"
      "hplipWithPlugin"
      "cups-bjnp"
      "cups-dymo"
      "cups-zj-58"
      "cups-kyocera"
      "cups-filters"
      "carps-cups"
      "cups-kyodialog3"
      "cups-brother-hl1110"
      "cups-toshiba-estudio"
      "cups-brother-hl1210w"
      "cups-brother-hl1210W"
      "cups-brother-hl3140cw"
      "cups-brother-hll2340dw"
      "cups-drv-rastertosag-gdi"
      "cups-kyocera-ecosys-m552x-p502x"
      "canon-cups-ufr2"
      "brscan5"
      "brscan4"
      "brother-udev-rule-type1"
      "brscan5-etc-files"
      "brscan4-etc-files"
    ];
  };
}
