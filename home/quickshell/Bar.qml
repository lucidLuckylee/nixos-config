// One masked layer surface for the bar and its menus.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
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

    readonly property int barHeight: 28

    // Measure target widths so the menu does not chase animated pill geometry.
    function menuGap(name) {
        const pills = cluster.children;
        let gap = cluster.anchors.rightMargin;
        let past = false;
        for (let i = 0; i < pills.length; i++) {
            const pill = pills[i];
            if (!pill.visible) continue;
            if (past) gap += pill.targetWidth + cluster.spacing;
            if (pill.menu === name) past = true;
        }
        return past ? gap : 0;
    }

    function menuWidth(name) {
        const pills = cluster.children;
        for (let i = 0; i < pills.length; i++)
            if (pills[i].menu === name) return pills[i].targetWidth;
        return 0;
    }

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

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // PipeWire audio values stay at their stubs until the node is tracked.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        return devices.find(d => d.type === DeviceType.Wifi) ?? null;
    }
    readonly property var wifiNetwork:
        wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property real wifiStrength: {
        if (!wifiNetwork) return 0;
        const raw = wifiNetwork.signalStrength;
        return raw > 1 ? raw / 100 : raw;
    }

    readonly property var connectedBtDevice: {
        if (!Bluetooth.defaultAdapter) return null;
        return Bluetooth.defaultAdapter.devices.values.find(d => d.connected) ?? null;
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

        pillGap: bar.menuGap(bar.shown)
        pillWidth: bar.menuWidth(bar.shown)

        WifiMenu { window: chrome }
        VolumeMenu { window: chrome }
        BluetoothFlyout { window: chrome }
        CalendarMenu { window: chrome }
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

        RowLayout {
            id: cluster
            anchors.right: parent.right
            // Match the menu frame so the rightmost indicator lines up with its pill.
            anchors.rightMargin: Tokens.spacing.medium
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Tokens.spacing.extraSmall

            StatusPill {
                menu: "wifi"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                glyph: {
                    if (!bar.wifiDevice || !Networking.wifiEnabled)
                        return String.fromCodePoint(0xf05aa);  // md-wifi-off
                    if (!bar.wifiNetwork)
                        return String.fromCodePoint(0xf092b);  // md-wifi-strength-alert-outline

                    if (bar.wifiStrength > 0.75) return String.fromCodePoint(0xf0928);
                    if (bar.wifiStrength > 0.5)  return String.fromCodePoint(0xf0925);
                    if (bar.wifiStrength > 0.25) return String.fromCodePoint(0xf0922);
                    return String.fromCodePoint(0xf091f);      // md-wifi-strength-1..4
                }

                label: bar.wifiNetwork
                    ? bar.wifiNetwork.name + " " + Math.round(bar.wifiStrength * 100) + "%"
                    : "offline"
            }

            StatusPill {
                menu: "volume"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                readonly property var audio: bar.sink ? bar.sink.audio : null

                glyph: {
                    if (!audio || audio.muted) return String.fromCodePoint(0xf075f);  // md-volume-mute
                    if (audio.volume > 0.5)    return String.fromCodePoint(0xf057e);  // md-volume-high
                    if (audio.volume > 0)      return String.fromCodePoint(0xf0580);  // md-volume-medium
                    return String.fromCodePoint(0xf057f);                             // md-volume-low
                }
                label: {
                    if (!audio) return "--";
                    const percent = Math.round(audio.volume * 100) + "%";
                    return audio.muted ? "(" + percent + ")" : percent;
                }
                alert: audio !== null && audio.muted
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
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                glyph: {
                    if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled)
                        return String.fromCodePoint(0xf00b2);  // md-bluetooth-off
                    if (bar.connectedBtDevice)
                        return String.fromCodePoint(0xf00b1);  // md-bluetooth-connect
                    return String.fromCodePoint(0xf00af);      // md-bluetooth
                }

                label: {
                    const device = bar.connectedBtDevice;
                    if (!device) return "";
                    const name = device.deviceName || device.name || device.address;
                    return device.batteryAvailable
                        ? name + " " + Math.round(device.battery * 100) + "%"
                        : name;
                }
            }

            StatusPill {
                menu: "clock"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)
                onActivated: bar.pillActivated(menu)

                label: Qt.formatDateTime(clock.date, "dd.MM. HH:mm")
            }
        }
    }
}
