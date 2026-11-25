// One masked layer surface for the bar and its menus.

import Quickshell
import Quickshell.Wayland
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    property string openMenu: ""
    property string shown: ""
    signal pillHover(string name, bool hovered)
    signal pillActivated(string name)

    readonly property alias shapeHovered: surface.hovered
    readonly property alias pointerPressed: surface.pressed
    readonly property bool plainPillHovered: chrome.hoverPill !== null
    // A menu that is taking typed input, like a Wi-Fi password; it stays open meanwhile.
    readonly property string typingMenu: chrome.typingMenu

    readonly property int barHeight: 28

    // Sway's binding mode, such as "resize"; "default" outside any mode.
    property string swayMode: "default"
    I3IpcListener {
        subscriptions: ["mode"]
        onIpcEvent: event => {
            if (event.type === "mode") bar.swayMode = JSON.parse(event.data).change;
        }
    }

    readonly property bool launching:
        Launcher.open && modelData !== undefined && Launcher.screen === modelData.name
    // Where clicks reach the launcher rather than closing it.
    readonly property rect launcherRect: launching
        ? Qt.rect(launcher.x, 0, launcher.width, barHeight) : Qt.rect(0, 0, 0, 0)

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Keep the surface large enough for any menu; reserve only the bar strip.
    implicitHeight: barHeight + chrome.maxBoxHeight

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight

    // Claim input only over the strip and the visible menu, leaving the desktop usable.
    mask: Region {
        x: 0
        y: 0
        width: bar.width
        height: bar.barHeight

        Region {
            intersection: Intersection.Combine

            x: chrome.boxX
            y: bar.barHeight
            width: chrome.boxWidth
            height: chrome.boxHeight

            bottomLeftRadius: chrome.boxRadius
            bottomRightRadius: chrome.boxRadius
        }
    }

    color: "transparent"
    WlrLayershell.namespace: "holo-bar"

    // The controls share an ancestor for reliable hover and gesture tracking.
    MenuSurface {
        id: surface
        anchors.fill: parent
    }

    // Take the keyboard only while a prompt or the launcher is up.
    WlrLayershell.keyboardFocus: openMenu === "pinentry" || typingMenu !== "" || launching
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    property string diskFree: "--"

    Process {
        id: df
        command: [Paths.diskFree]
        running: true
        stdout: SplitParser {
            onRead: line => bar.diskFree = line.trim()
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: df.running = true
    }

    Chrome {
        id: chrome
        parent: surface
        anchors.fill: parent

        barHeight: bar.barHeight
        open: bar.openMenu !== ""
        current: bar.shown

        pills: cluster

        WifiMenu { window: chrome }
        VolumeMenu { window: chrome }
        BluetoothFlyout { window: chrome }
        CalendarMenu { window: chrome }
        PinentryMenu { window: chrome }
    }

    Item {
        id: strip
        parent: surface
        // Reparenting does not preserve declaration order, so the strip must
        // stack above the chrome explicitly or its panel paints over the pills.
        z: 1

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: bar.barHeight

        Workspaces {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            monitor: bar.modelData ? bar.modelData.name : ""
        }

        LauncherField {
            id: launcher
            x: Math.round(parent.width / 5)
            width: cluster.x - x - Tokens.spacing.medium
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            active: bar.launching
        }

        RowLayout {
            id: cluster
            anchors.right: parent.right
            // Match the menu frame so the rightmost indicator lines up with its pill.
            anchors.rightMargin: Tokens.spacing.medium
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Tokens.spacing.extraSmall

            // Anchors the passphrase prompt; shown only while it is open or closing.
            StatusPill {
                menu: "pinentry"
                visible: bar.openMenu === "pinentry"
                    || (bar.shown === "pinentry" && chrome.reveal > 0.01)

                glyph: String.fromCodePoint(0xf033e)  // md-lock
                label: "passphrase"
            }

            // Shown while a Sway mode like resize is on; click leaves it.
            StatusPill {
                visible: bar.swayMode !== "default"
                clickable: true
                active: true
                onActivated: I3.dispatch("mode default")

                glyph: String.fromCodePoint(0xf0a68)  // md-resize
                label: bar.swayMode
            }

            // Always-on keeps the screens awake; click toggles it like Mod+Shift+m.
            StatusPill {
                clickable: true
                active: AlwaysOn.active
                onActivated: AlwaysOn.toggle()

                glyph: String.fromCodePoint(
                    AlwaysOn.active ? 0xf0208 : 0xf0209)  // md-eye / md-eye-off
                label: AlwaysOn.active ? "always-on" : ""
            }

            StatusPill {
                menu: "wifi"
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                readonly property var network: Status.wifiNetwork

                glyph: {
                    if (!Status.wifiLive) return Status.md(0xf05aa);  // md-wifi-off
                    if (!network) return Status.md(0xf092b);          // md-wifi-strength-alert-outline
                    return Status.wifiGlyph(Status.strength(network));
                }

                label: network
                    ? network.name + " " + Math.round(Status.strength(network) * 100) + "%"
                    : "offline"
            }

            StatusPill {
                menu: "volume"
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                glyph: Status.volumeGlyph(Status.audio)
                label: Status.volumeText(Status.audio)
                alert: Status.audio !== null && Status.audio.muted
                tint: Theme.warm
            }

            StatusPill {
                glyph: String.fromCodePoint(0xf02ca)  // md-harddisk
                label: bar.diskFree
            }

            StatusPill {
                readonly property var battery: UPower.displayDevice
                readonly property bool charging:
                    battery && battery.state === UPowerDeviceState.Charging
                readonly property real level: battery ? battery.percentage : 0

                visible: battery !== null && battery.isPresent

                glyph: {
                    if (!battery) return String.fromCodePoint(0xf0091);  // md-battery-unknown
                    if (level >= 0.995)
                        return String.fromCodePoint(charging ? 0xf0085 : 0xf0079);
                    if (level < 0.10 && !charging)
                        return String.fromCodePoint(0xf0083);            // md-battery-alert

                    const tenth = Math.max(1, Math.floor(level * 10));
                    const charged = [0, 0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d,
                                     0xf0089, 0xf089e, 0xf008a, 0xf008b];
                    return String.fromCodePoint(
                        charging ? charged[tenth] : 0xf0079 + tenth);
                }

                label: {
                    if (!battery) return "";
                    const percent = Math.round(level * 100) + "%";

                    const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
                    if (!seconds) return percent;

                    const hours = Math.floor(seconds / 3600);
                    const minutes = Math.floor((seconds % 3600) / 60);
                    return percent + " (" + hours + ":"
                        + String(minutes).padStart(2, "0") + ")";
                }

                alert: level < 0.25 && !charging
                tint: Theme.warm
            }

            StatusPill {
                menu: "bluetooth"
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                readonly property var device: Status.btConnected

                glyph: {
                    if (!Status.btLive) return Status.md(0xf00b2);  // md-bluetooth-off
                    if (device) return Status.md(0xf00b1);          // md-bluetooth-connect
                    return Status.md(0xf00af);                      // md-bluetooth
                }

                label: {
                    if (!device) return "";
                    const name = Status.deviceName(device);
                    return device.batteryAvailable
                        ? name + " " + Math.round(device.battery * 100) + "%"
                        : name;
                }
            }

            StatusPill {
                menu: "clock"
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                label: Qt.formatDateTime(clock.date, "dd.MM. HH:mm")
            }
        }
    }
}
