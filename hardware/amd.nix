{ config, pkgs, lib, ... }:
with lib;
let
  inherit (cfg);
in
{
  boot.initrd.kernelModules = [ "amdgpu" ];
}
