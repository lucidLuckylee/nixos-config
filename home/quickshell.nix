{ config, pkgs, ... }:

# The Quickshell session shell.
#
# Quickshell is a QtQuick toolkit for building Wayland shell surfaces: it loads
# a QML tree and turns the windows declared in it into layer-shell surfaces.
# What it draws here is one surface per monitor (./quickshell/Bar.qml): the bar
# across the top and the menus that hang off its pills, which are the same
# window and the same drawn shape (./quickshell/Chrome.qml) rather than a strip
# with boxes underneath it.
#
# This *is* the bar: sway's own `bars` list in ./linux.nix is empty and
# i3status is gone, because two bars is one bar too many. Everything the status
# line used to show — wifi, volume, free disk, the clock — is on this one,
# read from NetworkManager, PipeWire and the system clock directly instead of
# from a status line re-parsed once a second.
#
# The consequence worth knowing: if this crashes there is no bar at all rather
# than a bar without a status line. The systemd unit below restarts it, and
# `systemctl --user status quickshell` says what happened.
#
# ── Why the config directory is assembled here ──────────────────────────
# The QML lives in ./quickshell as real .qml files rather than as strings in
# this file: it is a UI that is meant to grow further menus, and QML embedded
# in a Nix string loses its indentation rules, its editor support and its
# diffs. Only the two things that genuinely come from the Nix side — the
# palette and the store path of the one generated helper — are written out as
# QML here, as singletons the static files import by name.

let
  theme = import ./colors.nix;
  colors = theme.colors;
  accent = theme.accent;
  workspaces = import ./workspaces.nix;

  # ── Free disk space ─────────────────────────────────────────────────
  # The one readout on the bar with no service behind it: nothing publishes
  # free space on a bus, so it is a `df` on a one-minute timer.
  #
  # A script in the store rather than an inline `sh -c` in the QML, because
  # the shell only inherits whatever PATH the systemd user manager happens to
  # have, and a bar that shows "--" on some logins and a number on others is
  # worse than either.
  #
  # --output=avail asks for the one column that is wanted, which also sidesteps
  # the wrapping a long device name causes in df's default layout: the parse is
  # "the second line, trimmed". (It cannot be combined with -P — df rejects the
  # two together — but with a single column there is nothing left to wrap.)
  diskFree = pkgs.writeShellScript "disk-free" ''
    ${pkgs.coreutils}/bin/df -h --output=avail / | ${pkgs.coreutils}/bin/tail -n1
  '';
  # ── Generated: the palette ──────────────────────────────────────────
  # ./colors.nix stays the single source of the scheme. Exposed as a Quickshell
  # Singleton, which is the one kind of QML singleton that needs no qmldir
  # entry, so the config directory stays a flat set of files.
  #
  # Only the roles the shell actually uses are here. Adding a colour means
  # adding it in colors.nix and then naming it below; nothing reads a literal
  # hex out of the QML.
  themeQml = pkgs.writeText "Theme.qml" ''
    pragma Singleton

    import Quickshell
    // `color` is a QtQuick type, not a QML language primitive: without this
    // import every property below fails with "color is not a type".
    import QtQuick

    Singleton {
        readonly property color background: "${colors.background}"
        readonly property color foreground: "${colors.foreground}"

        readonly property color primary:    "${accent.primary}"
        readonly property color panel:      "${accent.panel}"
        readonly property color line:       "${accent.line}"
        readonly property color textDim:    "${accent.textDim}"
        readonly property color textBright: "${accent.textBright}"
        readonly property color warm:       "${accent.warm}"
        readonly property color hot:        "${accent.hot}"

        // The raster dot, at the same pitch the terminal and Firefox use. Only
        // the flyout draws it — the bar is a flat field (see Bar.qml).
        readonly property color rasterDot: "${accent.rasterDot}"
        readonly property int dotGap: ${toString theme.dotGap}


        readonly property string fontFamily: "DejaVu Sans Mono"

        // Device class icons come out of the Nerd Font private use area, so
        // they need the patched family by its own name — fontconfig's fuzzy
        // match on "DejaVu Sans Mono" resolves to the unpatched font, which
        // has none of those codepoints and draws every one as a box.
        readonly property string iconFont: "DejaVuSansM Nerd Font Mono"
    }
  '';

  # ── Generated: store paths ──────────────────────────────────────────
  # QML cannot resolve a Nix store path on its own, and hardcoding one would go
  # stale on the next rebuild. Kept apart from Theme so the palette file stays
  # purely about colour.
  pathsQml = pkgs.writeText "Paths.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property string diskFree: "${diskFree}"
    }
  '';

  # ── Generated: the session's own shape ──────────────────────────────
  # Facts about this desktop that the shell has to agree with sway about. Right
  # now that is the order of the named workspaces: sway keeps them in the order
  # they were first opened, which is not an order anyone chose, so the bar sorts
  # by this list instead. ./workspaces.nix is the same file the keybindings in
  # ./linux.nix are built from, so the two cannot drift.
  sessionQml = pkgs.writeText "Session.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property var namedWorkspaces: [${
          pkgs.lib.concatMapStringsSep ", " (ws: ''"${ws.name}"'') workspaces.named
        }]
    }
  '';

  # ── The config directory ────────────────────────────────────────────
  # Quickshell wants one directory holding shell.qml and everything it imports
  # by name, so the hand-written files in ./quickshell and the three generated
  # singletons above are linked together into one store path.
  #
  # Every .qml in ./quickshell is picked up rather than listed: a new component
  # is a new file, and having to remember to name it here as well is a rebuild
  # that succeeds and a shell that fails at runtime with "Bar is not a type".
  #
  # This being a store path rather than ~/.config is what makes a rebuild
  # actually take effect — see the service below.
  configDir = pkgs.linkFarm "quickshell-config" ([
    { name = "Theme.qml"; path = themeQml; }
    { name = "Paths.qml"; path = pathsQml; }
    { name = "Session.qml"; path = sessionQml; }
  ] ++ map (file: {
    name = file;
    path = ./quickshell + "/${file}";
  }) (builtins.filter (pkgs.lib.hasSuffix ".qml")
       (builtins.attrNames (builtins.readDir ./quickshell))));
in {
  # Quickshell talks to BlueZ over D-Bus through its Quickshell.Bluetooth
  # module; nothing else is needed on the Quickshell side. The daemon itself is
  # enabled in the system config (hardware.bluetooth), not here.
  home.packages = [ pkgs.quickshell ];

  # Started with the session rather than from sway's config so that a crash is
  # restarted and shows up in `systemctl --user status quickshell` with a log,
  # instead of silently leaving the desktop without a bar.
  #
  # ExecStart points into the store, not at ~/.config, and that is deliberate:
  # home-manager restarts a user service when its *unit* changes, and a unit
  # that says "run the shell in ~/.config" is identical no matter what the QML
  # in it says. Editing a component would then rebuild happily and change
  # nothing on screen until the service was restarted by hand — or, worse,
  # after swaybar was removed, leave no bar at all. With the config directory's
  # hash in the command line, any change to any file is a new unit, and the
  # switch restarts it.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell session shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell --path ${configDir}/shell.qml";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
