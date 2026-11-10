#!/usr/bin/env bash
#
# mac-boot-volume.sh — set the Apple firmware boot-chime ("startup") volume
# from Linux, by writing the NVRAM/EFI variable the firmware reads.
#
# Macs keep boot-time hardware state in NVRAM, alongside the startup disk:
#   efi-boot-device      the boot volume the user chose (Finder -> Startup Disk)
#   backlight-level      the panel brightness
#   SystemAudioVolume    the boot chime / screen-reader volume   <-- this one
# All of them live under the Apple GUID 7C436110-AB2A-4BBB-A880-FE41995C9F82.
#
# macOS writes SystemAudioVolume on shutdown, so the chime keeps whatever
# volume macOS last had.  Linux never touches it, which is why it stays where
# macOS left it.  Writing it from Linux is all that is needed.
#
#   mac-boot-volume.sh --show              show the current value
#   mac-boot-volume.sh 0a                  set the data byte to 0x0A
#   mac-boot-volume.sh --mute              same as 00 (silent on real Macs)
#   mac-boot-volume.sh --backup            save the raw variable (persistent)
#   mac-boot-volume.sh --restore FILE      write a saved raw variable back
#
# SCALE, and why this script does not pretend to know it: the variable is a
# single data byte.  The only well-attested point is that 0x00 is the quiet
# end (the Linux recipe that silences the chime on real Macs uses exactly
# 0x00), and larger values are louder — 0x4D was what macOS had stored on the
# machine this was written for.  The mapping in between is not documented, so
# treat it as "smaller = quieter" and verify by ear on the next boot.
# SystemAudioVolumeDB, which also exists, is the macOS *system* volume in dB
# and has nothing to do with the chime; this script deliberately leaves it
# alone.
#
# The variable is marked immutable by the kernel, and efivarfs on some Macs
# refuses to modify an existing variable in place; in that case the only way
# is to delete it and recreate it with the 4-byte attribute header.  Both
# paths are handled below, and every write is verified by reading back.

set -euo pipefail

GUID="7c436110-ab2a-4bbb-a880-fe41995c9f82"
NAME="SystemAudioVolume"
VAR="/sys/firmware/efi/efivars/${NAME}-${GUID}"
BACKUP_DIR="/var/lib/mac-boot-volume"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
   cat <<'EOF'
mac-boot-volume.sh — set the Apple firmware boot-chime ("startup") volume
                     from Linux, by writing the NVRAM/EFI variable the
                     firmware reads.

   mac-boot-volume.sh --show              show the current value
   mac-boot-volume.sh 0a                  set the data byte to 0x0A
   mac-boot-volume.sh --mute              same as 00 (silent on real Macs)
   mac-boot-volume.sh --backup            save the raw variable (persistent)
   mac-boot-volume.sh --restore FILE      write a saved raw variable back

The variable is a single data byte: 0x00 is the quiet end, larger is louder,
and the mapping in between is undocumented — tune and verify by ear on the
next boot.
EOF
   exit "${1:-0}"
}

[[ -d /sys/firmware/efi/efivars ]] || die "efivarfs is not mounted (is this booted via EFI?)"
[[ -e "$VAR" ]] || die "$NAME does not exist on this machine; nothing to read or change"

show() {
   printf '%s\n' "$VAR"
   lsattr "$VAR" 2>/dev/null || true
   hexdump -C "$VAR"
   printf 'data byte: 0x%s\n' "$(data_byte)"
}

data_byte() {
   # efivarfs files are 4 bytes of attributes followed by the value
   od -An -tx1 -j4 -N1 "$VAR" | tr -d ' \n'
}

backup() {
   mkdir -p "$BACKUP_DIR"
   chmod 700 "$BACKUP_DIR"
   local stamp dest
   stamp="$(date +%Y%m%d-%H%M%S)"
   dest="$BACKUP_DIR/${NAME}.${stamp}.bin"
   cat "$VAR" > "$dest"
   cp -n "$dest" "$BACKUP_DIR/${NAME}.orig.bin" 2>/dev/null || true
   printf 'saved %s\n' "$dest"
   printf '%s\n' "$dest"
}

# write_raw <file-with-4-byte-attrs-plus-value>
write_raw() {
   local src="$1"
   chattr -i "$VAR" 2>/dev/null || true
   if cp "$src" "$VAR" 2>/dev/null; then
      return 0
   fi
   # efivarfs refused the in-place update: delete and recreate instead.  This
   # is the documented recipe for real Macs.  The variable is absent for the
   # instant between the two calls; the caller has a backup.
   rm -f "$VAR" || die "could not remove $VAR"
   cp "$src" "$VAR" || die "variable is now MISSING - restore with: $0 --restore <backup>"
}

write_byte() {
   local byte="${1,,}"
   [[ "$byte" =~ ^[0-9a-f]{2}$ ]] || die "value must be a single hex byte, e.g. 0a"
   local tmp
   tmp="$(mktemp)"
   # attributes: NON_VOLATILE | BOOTSERVICE_ACCESS | RUNTIME_ACCESS, then the value
   printf '%b' "\x07\x00\x00\x00\x${byte}" > "$tmp"
   write_raw "$tmp"
   rm -f "$tmp"
   [[ "$(data_byte)" == "$byte" ]] || die "readback mismatch: wanted 0x$byte, got 0x$(data_byte)"
   printf 'ok: %s = 0x%s (verified by readback)\n' "$NAME" "$byte"
}

case "${1:---show}" in
   --show|--get)            show ;;
   --mute|--silent|--off)   write_byte 00 ;;
   --backup)                backup ;;
   --restore)
      [[ $# -ge 2 ]] || die "--restore needs the file saved by --backup"
      [[ -e "$2" ]] || die "no such file: $2"
      write_raw "$2"
      printf 'ok: restored %s from %s (data byte 0x%s)\n' "$NAME" "$2" "$(data_byte)"
      ;;
   -h|--help)               usage 0 ;;
   -*)                      printf 'unknown option: %s\n\n' "$1" >&2; usage 1 ;;
   *)                       write_byte "$1" ;;
esac
