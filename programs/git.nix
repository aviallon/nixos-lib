{config, pkgs, lib, myLib, ...}:
with lib;
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      init = {
        defaultBranch = "main";
      };
      user = {
        email = "antoine@lesviallon.fr";
        name = "Antoine Viallon";
      };
      core.compression = 6;
      commit.gpgSign = lib.mkDefault true;
      diff = {
        algorithm = "histogram";
        renames = true;
      };
      feature = {
        manyFiles = true;
      };
      fetch.prune = true;
      fetch.negotiationAlgorithm = "skipping";
      fetch.parallel = config.aviallon.general.cpu.threads;
      pack.threads = myLib.math.log2 config.aviallon.general.cpu.threads;
      checkout.workers = config.aviallon.general.cpu.threads / 2;
      gpg.program = "${pkgs.gnupg}/bin/gpg";
      format.pretty = "format:%C(yellow)%H (%t)%Creset %Cblue%aN (%cN)%Creset%Cred% G?%Creset - %Cgreen%ar%Creset %d %n    %s%n";
    };
  };
}
