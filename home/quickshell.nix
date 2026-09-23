{ pkgs, lib, ... }:

# Quickshell bar and menus. QML components live in ./quickshell; Nix generates
# the palette, helper paths and workspace order.

let
  theme = import ./colors.nix;
  inherit (theme) colors accent;
  workspaces = import ./workspaces.nix;
  alwaysOn = import ./always-on.nix { inherit pkgs; };
  agenda = import ./agenda.nix { inherit pkgs; };

  # df is the only polled readout; expose a store-backed helper to the service.
  diskFree = pkgs.writeShellScript "disk-free" ''
    ${pkgs.coreutils}/bin/df -h --output=avail / | ${pkgs.coreutils}/bin/tail -n1
  '';

  # Executables on PATH for the launcher, as wmenu-run lists them.
  commands = pkgs.writeShellScript "list-commands" ''
    IFS=:
    ${pkgs.findutils}/bin/find -L $PATH -maxdepth 1 -type f -executable -printf '%f\n' 2>/dev/null \
      | ${pkgs.coreutils}/bin/sort -u
  '';

  # Generate the QML palette from the shared theme.
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

  # Pass helper store paths into QML.
  pathsQml = pkgs.writeText "Paths.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property string diskFree: "${diskFree}"
        readonly property string alwaysOn: "${alwaysOn}"
        readonly property string agenda: "${agenda}"
        readonly property string commands: "${commands}"
    }
  '';

  # Share named workspace order with the Sway keybindings.
  sessionQml = pkgs.writeText "Session.qml" ''
    pragma Singleton

    import Quickshell

    Singleton {
        readonly property var namedWorkspaces: [${
          lib.concatMapStringsSep ", " (ws: ''"${ws.name}"'') workspaces.named
        }]
    }
  '';

  # Assemble all QML components and generated singletons in one directory.
  configDir = pkgs.linkFarm "quickshell-config" ([
    { name = "Theme.qml"; path = themeQml; }
    { name = "Paths.qml"; path = pathsQml; }
    { name = "Session.qml"; path = sessionQml; }
  ] ++ lib.mapAttrsToList (file: _: {
    name = file;
    path = ./quickshell + "/${file}";
  }) (lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".qml" file)
       (builtins.readDir ./quickshell)));
in {
  # Quickshell talks to BlueZ over D-Bus through its Quickshell.Bluetooth
  # module; nothing else is needed on the Quickshell side. The daemon itself is
  # enabled in the system config (hardware.bluetooth), not here.
  home.packages = [ pkgs.quickshell ];

  # Mod+d opens the launcher in the bar.
  wayland.windowManager.sway.config.menu =
    "${pkgs.quickshell}/bin/quickshell ipc --path ${configDir}/shell.qml call launcher toggle";

  # Include the config store path in ExecStart so Home Manager restarts the
  # service whenever a QML component changes.
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
