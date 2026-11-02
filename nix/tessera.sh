#!/bin/sh
# Start Tessera, or hand a command to the one already running.
#
# `tessera` with no arguments is the shell itself. Anything else is a command
# for a running instance and goes over Quickshell's IPC socket: the `qs` client
# only connects and writes a line, it never loads the QML, so a keybinding pays
# for a process spawn and nothing more. With no instance up the command says so
# and fails -- it never quietly becomes the shell.
#
# In the package @qs@ and @shell@ are substituted. Run straight from a checkout
# they are not, and the script finds the QML next to itself and `qs` on PATH.

set -u

QS="@qs@"
SHELL_DIR="@shell@"

case $QS in @*) QS=qs ;; esac
case $SHELL_DIR in @*) SHELL_DIR="$(cd "$(dirname "$0")/../shell" && pwd)" ;; esac

usage() {
  cat <<'EOF'
tessera — a desktop shell for niri

Running `tessera` with no arguments starts the shell. Running it again while
an instance is up forwards the command to it:

  tessera toggle launcher
  tessera toggle control-center
  tessera toggle calendar
  tessera toggle clipboard
  tessera toggle notification-center
  tessera toggle weather
  tessera control-center wifi   open the control center on a page
                                (wifi, bluetooth, proxy, mixer, mixer-input,
                                record, session)
  tessera pick-color            pick a colour off the screen, onto the clipboard
  tessera desktop edit          rearrange the desktop widgets (also: on, off)
  tessera reload                reread the config
  tessera windows               list the shell's windows
  tessera quit                  stop the shell
EOF
}

# The icon theme Quickshell should draw from.
#
# Qt has no idea what GTK was told, and left alone it falls back to hicolor,
# which carries almost nothing. GTK's own settings file is what Stylix and
# nwg-look write, and dconf is what GNOME's settings write, so those two are
# asked in that order.
icon_theme() {
  settings="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini"
  if [ -r "$settings" ]; then
    theme=$(sed -n 's/^[[:space:]]*gtk-icon-theme-name[[:space:]]*=[[:space:]]*//p' "$settings" | tail -n 1)
    if [ -n "$theme" ]; then
      printf '%s' "$theme"
      return
    fi
  fi
  if command -v dconf >/dev/null 2>&1; then
    dconf read /org/gnome/desktop/interface/icon-theme 2>/dev/null | tr -d "'"
  fi
}

start() {
  if [ -z "${QS_ICON_THEME:-}" ]; then
    theme=$(icon_theme)
    export QS_ICON_THEME="${theme:-Adwaita}"
  fi

  # Reloading on every file save is what makes Quickshell pleasant to develop
  # against and alarming to live with: an edit in the store cannot happen, and
  # the popup announcing a reload is not something a desktop should show.
  if [ "${TESSERA_DEV:-}" != 1 ]; then
    export QS_DISABLE_FILE_WATCHER=1
    export QS_NO_RELOAD_POPUP=1
  fi

  exec "$QS" -p "$SHELL_DIR" --no-duplicate
}

call() {
  if ! reply=$("$QS" -p "$SHELL_DIR" ipc call tessera "$@" 2>&1); then
    case $reply in
    *"o running instances"* | *"not running"* | *"No instance"*)
      echo "tessera: not running" >&2
      exit 1
      ;;
    esac
    # Asking the shell to quit and then complaining that it went is not a
    # failure worth reporting.
    [ "$1" = quit ] && exit 0
    printf '%s\n' "$reply" >&2
    exit 1
  fi
  [ -n "$reply" ] && printf '%s\n' "$reply"
  exit 0
}

[ $# -eq 0 ] && start

command=$1
shift

case $command in
help | --help | -h)
  usage
  ;;
toggle)
  [ $# -ge 1 ] || { echo "usage: tessera toggle <window>" >&2; exit 2; }
  call toggle "$1"
  ;;
control-center)
  call controlCenter "${1:-main}"
  ;;
desktop)
  case ${1:-edit} in
  edit | on | off) call desktop "${1:-edit}" ;;
  *) echo "usage: tessera desktop [edit|on|off]" >&2; exit 2 ;;
  esac
  ;;
pick-color | pick-colour)
  call pickColor
  ;;
reload)
  call reload
  ;;
windows)
  call windows
  ;;
quit)
  call quit
  ;;
*)
  echo "tessera: unknown command: $command" >&2
  echo 'run "tessera help" for the list' >&2
  exit 2
  ;;
esac
