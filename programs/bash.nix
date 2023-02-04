{ config, pkgs, lib, ... }:
with lib;
{
  options.aviallon.programs.bash = {
    powerline = mkOption {
      description = "Enable powerline prompt";
      default = true;
      example = false;
      type = types.bool;
    };
  };

  config = {
    programs.bash.promptInit = mkAfter ''
      _prompt() {
        PS1="$(${pkgs.powerline-go}/bin/powerline-go -error $? -jobs $(jobs -p | wc -l))"
      }
      if [ "$TERM" != "dumb" ] && [ "$TERM" != "linux" ]; then
        export PROMPT_COMMAND="_prompt"
      fi
      export -f _prompt
    '';
  };
}
