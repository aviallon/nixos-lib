{config, ...}:
{
  imports = [
    ./hardening.nix
    ./tpm.nix
    ./encryption.nix
  ];
}
