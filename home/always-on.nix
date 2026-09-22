# Always-on keeps the screens awake by stopping swayidle. A binding mode would
# do the same, but a mode swallows every other keybinding while it is active,
# so this is a plain toggle. The runtime state file lets the Quickshell bar
# follow changes without polling; both the key chord and the bar run this.
{ pkgs }:

pkgs.writeShellScript "sway-always-on" ''
  set -eu
  # Usage: sway-always-on [toggle]
  systemctl=${pkgs.systemd}/bin/systemctl
  state="''${XDG_RUNTIME_DIR:-/tmp}/sway-always-on"

  if [ "''${1:-}" = toggle ]; then
    if $systemctl --user is-active --quiet swayidle.service; then
      $systemctl --user stop swayidle.service
    else
      $systemctl --user start swayidle.service
    fi
  fi

  if $systemctl --user is-active --quiet swayidle.service; then
    printf off > "$state"
  else
    printf on > "$state"
  fi
''
