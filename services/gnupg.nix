{ config, pkgs, lib, ... }:
with lib;
let
  gpgNoTTY = pkgs.writeShellScriptBin "gpg-no-tty" ''
    exec ${pkgs.gnupg}/bin/gpg --batch --no-tty "$@"
  '';
  pinentrySwitcher = pkgs.callPackage ../packages/pinentry.nix {};
in {
  config = {

    programs.gnupg = {
      agent.enable = true;
      dirmngr.enable = true;
      
      agent.pinentryPackage = pkgs.pinentry-all;
      agent.enableSSHSupport = true;
      agent.enableExtraSocket = true;
      agent.enableBrowserSocket = true;
    };

    environment.interactiveShellInit = mkAfter ''
      ${config.programs.gnupg.package}/bin/gpg-connect-agent --quiet updatestartuptty /bye
    '';

    environment.shellInit = ''
      alias gpg=${gpgNoTTY}/bin/gpg-no-tty
    '';

    environment.systemPackages = [
      gpgNoTTY
    ];
  
  };
}
