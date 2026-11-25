// Bluetooth power, discovery and device actions.

import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "bluetooth"

    readonly property var adapter: Status.btAdapter
    readonly property bool live: Status.btLive

    readonly property int gap: Tokens.spacing.small
    readonly property int maxRows: 3
    // A single device or none fits one column; two columns would leave half the box empty.
    readonly property int columns: devices.length > 1 ? 2 : 1
    readonly property int rows: live
        ? Math.min(maxRows, Math.max(1, Math.ceil(devices.length / columns)))
        : 0

    contentWidth: !live ? Tokens.size.chip : columns === 2 ? 480 : 300
    contentHeight: listHeight(rows)
    maxContentHeight: listHeight(maxRows)

    function listHeight(n) {
        return Tokens.size.control + (n > 0 ? n * (Tokens.size.row + gap) : 0);
    }

    readonly property var devices: {
        if (!live || !adapter) return [];

        return [...adapter.devices.values].sort((a, b) =>
            (b.connected - a.connected)
            || (b.paired - a.paired)
            || Status.deviceName(a).localeCompare(Status.deviceName(b))
        ).slice(0, 2 * maxRows);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        RadioHeader {
            page: menu
            onGlyph: String.fromCodePoint(0xf00af)   // md-bluetooth
            offGlyph: String.fromCodePoint(0xf00b2)  // md-bluetooth-off
            live: menu.live
            available: menu.adapter !== null
            scanning: menu.adapter !== null && menu.adapter.discovering

            onPowerToggled: menu.adapter.enabled = !menu.adapter.enabled
            onScanToggled: menu.adapter.discovering = !menu.adapter.discovering
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

                        page: menu
                        device: modelData
                        entryIndex: index
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.size.row
                verticalAlignment: Text.AlignVCenter
                visible: menu.devices.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                text: menu.adapter && menu.adapter.discovering
                    ? "scanning…" : "no devices"
            }

            Item { Layout.fillHeight: true }
        }
    }
}
