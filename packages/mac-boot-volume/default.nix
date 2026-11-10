{
  lib,
  coreutils,
  e2fsprogs,
  util-linux,
  writeShellApplication,
}:

writeShellApplication {
  name = "mac-boot-volume";

  # chattr/lsattr live in e2fsprogs, od in coreutils, hexdump in util-linux.
  runtimeInputs = [
    e2fsprogs
    coreutils
    util-linux
  ];

  text = builtins.readFile ./mac-boot-volume.sh;

  meta = {
    description = "Set the Apple firmware boot-chime (startup) volume from Linux, via efivarfs";
    homepage = "https://github.com/aviallon/nixos-lib";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
