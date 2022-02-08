{config, ...}:
{
  imports = [
    ./general.nix
    ./boot.nix
    ./desktop.nix
    ./home-manager.nix
    ./network.nix
    ./packages.nix
    ./services.nix
    ./filesystems.nix
    ./hardening.nix
    ./hardware.nix
    ./laptop.nix
    ./overlays.nix
    ./non-persistence.nix
  ];
}