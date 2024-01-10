{ config, pkgs, lib, ... }:
with lib;
let
  gpgNoTTY = pkgs.writeShellScriptBin "gpg-no-tty" ''
    exec ${pkgs.gnupg}/bin/gpg --batch --no-tty "$@"
  '';
in {
  config = {

    programs.gnupg = {
      agent.enable = true;
      dirmngr.enable = true;
      agent.pinentryFlavor = "curses"; # overriden anyway
      agent.enableSSHSupport = true;
      agent.enableExtraSocket = true;
      agent.enableBrowserSocket = true;
    };

    environment.shellInit = ''
      if tty --silent; then
        export GPG_TTY="$(tty)"
        gpg-connect-agent /bye
        export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
      else
        alias gpg=${gpgNoTTY}/bin/gpg-no-tty
      fi
    '';

    environment.systemPackages = [
      gpgNoTTY
    ];
  
    systemd.user.services.gpg-agent = let
      pinentrySwitcher = pkgs.callPackage ../packages/pinentry.nix {};
      cfg = config.programs.gnupg;
    in {
      restartTriggers = [ pinentrySwitcher ];
      restartIfChanged = true;
    
      serviceConfig.ExecStart = mkOverride 30 [ "" ''
        ${cfg.package}/bin/gpg-agent --supervised \
          --pinentry-program ${pinentrySwitcher}/bin/pinentry
        '' ];
    };
  };
}
