{ config, pkgs, lib, ... }:
with lib;
{
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
      export GPG_TTY="$(tty)"
      gpg-connect-agent /bye
      export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"
    '';
  
    systemd.user.services.gpg-agent = let
      pinentrySwitcher = pkgs.callPackage ../packages/pinentry.nix {};
      cfg = config.programs.gnupg;
    in {
      restartTriggers = [ pinentrySwitcher ];
      restartIfChanged = true;
    
      serviceConfig.ExecStart = [ "" ''
        ${cfg.package}/bin/gpg-agent --supervised \
          --pinentry-program ${pinentrySwitcher}/bin/pinentry
        '' ];
    };
  };
}
