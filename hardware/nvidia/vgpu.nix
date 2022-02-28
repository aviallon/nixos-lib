{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.hardware;
  useVgpu = (cfg.useProprietary &&
            (cfg.gpuVendor == "nvidia") &&
            (versionOlder config.boot.kernelPackages.kernel.version "5.10"));
in
{
  imports = [
    <nixos-nvidia-vgpu>
    # (optional useVgpu (builtins.fetchTarball "https://github.com/danielfullmer/nixos-nvidia-vgpu/archive/master.tar.gz"))
  ];

  config = mkIf useVgpu {
    hardware.nvidia.vgpu.enable = true; # Enable NVIDIA KVM vGPU + GRID driver
    hardware.nvidia.vgpu.unlock.enable = true; # Unlock vGPU functionality on consumer cards using DualCoder/vgpu_unlock project.
  };
}
