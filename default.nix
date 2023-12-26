{config, ...}:
{
  imports = [
    ./general.nix
    ./nix
    ./boot.nix
    ./desktop
    ./network.nix
    ./packages.nix
    ./services
    ./filesystems.nix
    ./security
    ./hardware
    ./laptop.nix
    ./power.nix
    ./overlays.nix
    ./optimizations
    ./non-persistence.nix
    ./windows
  ];
}
