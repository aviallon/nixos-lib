{ config, pkgs, ...}:
{
  imports = [
    ./jupyterhub.nix
    ./gnupg.nix
  ];
}
