{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.hardware.nvidia;
  vgpu-git = fetchGit {
    url = "https://github.com/danielfullmer/nixos-nvidia-vgpu.git";
    rev = "a4be77969dc2a8acbe3a4882ba5f0324cca138b6";
    ref = "master";
  };
  nixos-nvidia-vgpu = import vgpu-git {
    inherit config;
    inherit pkgs;
    inherit lib;
  };
  useVgpu = (
    cfg.enable && cfg.useProprietary &&
    (versionOlder config.boot.kernelPackages.kernel.version "5.10")
  );
in
{
  imports = [
    nixos-nvidia-vgpu
  ];

  config = mkIf useVgpu {
    hardware.nvidia.vgpu.enable = true; # Enable NVIDIA KVM vGPU + GRID driver
    hardware.nvidia.vgpu.unlock.enable = true; # Unlock vGPU functionality on consumer cards using DualCoder/vgpu_unlock project.
  };
}
