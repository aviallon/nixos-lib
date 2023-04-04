{ writeShellScriptBin, pinentry, ... }:
writeShellScriptBin "pinentry" ''
  flavor=
  if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    case "$XDG_CURRENT_DESKTOP" in
      KDE|LXQT)
        flavor="qt" ;;
      XFCE)
        flavor="gtk2" ;;
      Gnome)
        flavor="gnome3" ;;
      *)
        echo "Unknown desktop '$XDG_CURRENT_DESKTOP', use 'gnome3'" >&2
        flavor="gnome3" ;;
    esac
  elif [ -z "$XAUTHORITY" -a -z "$WAYLAND_DISPLAY" ]; then
    echo "No Xauthority nor Wayland display, using curses" >&2
    flavor="curses"
  fi

  if [ -z "$flavor" ]; then
    echo "WARNING: pinentry flavor could not be detected, use 'curses'" >&2
    flavor="curses"
  fi

  declare -A pinentryFlavors
  pinentryFlavors["qt"]="${pinentry.qt}"
  pinentryFlavors["gtk2"]="${pinentry.gtk2}"
  pinentryFlavors["gnome"]="${pinentry.gnome3}"
  pinentryFlavors["curses"]="${pinentry.curses}"

  echo "Selected flavor: $flavor" >&2

  exec ''${pinentryFlavors[$flavor]}/bin/pinentry
''

