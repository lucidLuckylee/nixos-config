// Bluetooth power, discovery and device actions.

import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "bluetooth"

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool live: adapter !== null && adapter.enabled

    readonly property int gap: Tokens.spacing.small
    readonly property int headerHeight: 22
    readonly property int rowHeight: 30
    readonly property int columns: 2

    readonly property int maxRows: 3

    readonly property int rows: live
        ? Math.min(maxRows, Math.max(1, Math.ceil(devices.length / columns)))
        : 0

    contentWidth: live ? 480 : 26
    contentHeight: headerHeight
        + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + maxRows * (rowHeight + gap) - gap

    readonly property var devices: {
        if (!live) return [];

        return [...adapter.devices.values].sort((a, b) =>
            (b.connected - a.connected)
            || (b.paired - a.paired)
            || (a.deviceName || a.name || a.address)
                .localeCompare(b.deviceName || b.name || b.address)
        ).slice(0, columns * maxRows);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            Chip {
                id: power

                x: Math.max(0, Math.min(parent.width - width, menu.pillAnchor))
                anchors.verticalCenter: parent.verticalCenter

                glyph: String.fromCodePoint(
                    menu.live ? 0xf00af    // md-bluetooth
                              : 0xf00b2)   // md-bluetooth-off
                active: menu.live
                available: menu.adapter !== null
                onToggled: menu.adapter.enabled = !menu.adapter.enabled

            }

            Chip {
                x: power.x - width - Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                opacity: menu.live ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { Anim { motion: Motion.fastEffect } }

                glyph: String.fromCodePoint(0xf0349)  // md-magnify
                active: menu.adapter !== null && menu.adapter.discovering
                available: menu.live
                working: menu.adapter !== null && menu.adapter.discovering
                onToggled: menu.adapter.discovering = !menu.adapter.discovering
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            opacity: menu.live ? 1 : 0
            visible: opacity > 0
            active: menu.live || opacity > 0
            Behavior on opacity { Anim { motion: Motion.fastEffect } }

            sourceComponent: deviceList
        }
    }

    Component {
        id: deviceList

        ColumnLayout {
            spacing: menu.gap

            GridLayout {
                Layout.fillWidth: true
                columns: menu.columns
                columnSpacing: Tokens.spacing.large
                rowSpacing: menu.gap

                Repeater {
                    model: menu.devices

                    DeviceRow {
                        required property var modelData
                        required property int index

                        device: modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.rowHeight
                        entryDelay: index * 40
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.rowHeight
                verticalAlignment: Text.AlignVCenter
                visible: menu.devices.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small
                text: menu.adapter && menu.adapter.discovering
                    ? "scanning…" : "no devices"
            }

            Item { Layout.fillHeight: true }
        }
    }
}
