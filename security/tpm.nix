{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.security.tpm;
in {
  options.aviallon.security.tpm = {
    enable = (mkEnableOption "TPM") // { default = true; };
    tpm1_2.enable = mkEnableOption "TPM 1.2 support";
  };
  config = mkIf cfg.enable {
    security.tpm2 = {
      enable = true;
      tctiEnvironment.enable = true;
      pkcs11.enable = true;
    };    

    environment.systemPackages = [
      pkgs.tpm2-tools
    ] ++ optional cfg.tpm1_2.enable pkgs.tpm-tools;

    services.tcsd = mkIf cfg.tpm1_2.enable {
      enable = true;
    };
  };
}
