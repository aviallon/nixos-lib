{ config, ... }:
{
  imports = [
    ./htop.nix
    ./bash.nix
    ./git.nix
    ./nano.nix
    ./nvtop.nix
    ./libreoffice.nix
  ];
}
