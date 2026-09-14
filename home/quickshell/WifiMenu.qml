// Wi-Fi radio, scanning and network actions.

import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "wifi"

    readonly property var device: {
        const devices = Networking.devices.values;
        return devices.find(d => d.type === DeviceType.Wifi) ?? null;
    }

    readonly property bool live: device !== null && Networking.wifiEnabled

    readonly property int gap: Tokens.spacing.small
    readonly property int headerHeight: 22
    readonly property int rowHeight: 30

    readonly property int maxRows: 5

    readonly property int rows: live ? Math.min(maxRows, Math.max(1, networks.length)) : 0

    contentWidth: live ? 300 : 26
    contentHeight: headerHeight + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + maxRows * (rowHeight + gap) - gap

    // Accept either fractional or percentage signal strength.
    function normalised(raw) {
        return raw > 1 ? raw / 100 : raw;
    }

    readonly property var networks: {
        if (!live) return [];

        return [...device.networks.values]
            .filter(n => n.name)
            .sort((a, b) =>
                (b.connected - a.connected)
                || (b.known - a.known)
                || (menu.normalised(b.signalStrength) - menu.normalised(a.signalStrength))
                || a.name.localeCompare(b.name)
            ).slice(0, maxRows);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            Chip {
                id: radio

                x: Math.max(0, Math.min(parent.width - width, menu.pillAnchor))
                anchors.verticalCenter: parent.verticalCenter

                glyph: String.fromCodePoint(
                    menu.live ? 0xf05a9    // md-wifi
                              : 0xf05aa)   // md-wifi-off
                active: menu.live

                available: menu.device !== null && Networking.wifiHardwareEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            Chip {
                x: radio.x - width - Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                opacity: menu.live ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { motion: Motion.fastEffect } }

                glyph: String.fromCodePoint(0xf0349)  // md-magnify
                active: menu.device !== null && menu.device.scannerEnabled
                available: menu.live
                working: menu.device !== null && menu.device.scannerEnabled
                onToggled: menu.device.scannerEnabled = !menu.device.scannerEnabled
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            opacity: menu.live ? 1 : 0
            visible: opacity > 0
            active: menu.live || opacity > 0
            Behavior on opacity { Anim { motion: Motion.fastEffect } }

            sourceComponent: networkList
        }
    }

    Component {
        id: networkList

        ColumnLayout {
            spacing: menu.gap

            Repeater {
                model: menu.networks

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property real strength: menu.normalised(modelData.signalStrength)

                    readonly property bool busy: modelData.stateChanging

                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.rowHeight

                    opacity: 0
                    scale: 0.7
                    Component.onCompleted: entry.start()

                    SequentialAnimation {
                        id: entry
                        PauseAnimation { duration: row.index * 40 }
                        ParallelAnimation {
                            Anim {
                                target: row; property: "opacity"
                                to: 1; motion: Motion.effect
                            }
                            Anim {
                                target: row; property: "scale"
                                to: 1; motion: Motion.spatial
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        color: row.modelData.connected
                            ? Theme.background
                            : (rowHover.hovered ? Qt.alpha(Theme.background, 0.10) : "transparent")

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.medium
                        spacing: Tokens.spacing.small

                        Text {
                            text: {
                                const s = row.strength;
                                if (s > 0.75) return String.fromCodePoint(0xf0928);
                                if (s > 0.5)  return String.fromCodePoint(0xf0925);
                                if (s > 0.25) return String.fromCodePoint(0xf0922);
                                return String.fromCodePoint(0xf091f);  // md-wifi-strength-1..4
                            }
                            color: row.modelData.connected
                                ? Theme.primary : Qt.alpha(Theme.background, 0.75)
                            font.family: Theme.iconFont
                            font.pixelSize: Tokens.fontSize.normal

                            Behavior on color { CAnim { motion: Motion.fastEffect } }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.spacing.extraSmall
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.modelData.connected
                                ? Theme.primary
                                : Qt.alpha(Theme.background, row.modelData.known ? 1 : 0.7)
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }

                        Text {
                            text: Math.round(row.strength * 100) + "%"
                            color: row.modelData.connected
                                ? Qt.alpha(Theme.primary, 0.8)
                                : Qt.alpha(Theme.background, 0.6)
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }

                        Text {
                            id: link
                            text: String.fromCodePoint(
                                row.modelData.connected ? 0xf0338    // md-link-off
                                                        : 0xf0337)   // md-link
                            color: row.busy ? Theme.warm
                                 : row.modelData.connected ? Theme.primary
                                 : (linkHover.hovered ? Theme.background
                                                      : Qt.alpha(Theme.background, 0.6))
                            font.family: Theme.iconFont
                            font.pixelSize: Tokens.fontSize.normal
                            leftPadding: Tokens.spacing.extraSmall
                            rightPadding: Tokens.spacing.extraSmall

                            Behavior on color { CAnim { motion: Motion.fastEffect } }

                            SequentialAnimation on opacity {
                                running: row.busy
                                loops: Animation.Infinite
                                onStopped: link.opacity = 1
                                NumberAnimation { from: 1; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.3; to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }

                            HoverHandler { id: linkHover }
                            TapHandler {
                                enabled: !row.busy
                                // Secured unknown networks need credentials from an external network manager.
                                onTapped: {
                                    if (row.modelData.connected) row.modelData.disconnect();
                                    else row.modelData.connect();
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.rowHeight
                verticalAlignment: Text.AlignVCenter
                visible: menu.networks.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small
                text: menu.device && menu.device.scannerEnabled
                    ? "scanning…" : "no networks"
            }

            Item { Layout.fillHeight: true }
        }
    }
}
