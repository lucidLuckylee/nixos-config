// Bluetooth device status with pairing, connection and forget actions.

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

Item {
    id: row

    required property BluetoothDevice device

    property int entryDelay: 0

    readonly property bool known: device.paired || device.bonded
    readonly property bool busy: device.pairing
        || device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting

    implicitHeight: 30

    opacity: 0
    scale: 0.7
    Component.onCompleted: entry.start()

    SequentialAnimation {
        id: entry
        PauseAnimation { duration: row.entryDelay }
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

    readonly property string glyph: {
        const icon = device.icon || "";
        const md = cp => String.fromCodePoint(cp);
        if (icon.includes("headset"))    return md(0xf02ce); // md-headset
        if (icon.includes("headphone"))  return md(0xf02cb); // md-headphones
        if (icon.includes("speaker") || icon.includes("audio"))
            return md(0xf04c3);                              // md-speaker
        if (icon.includes("mouse"))      return md(0xf037d); // md-mouse
        if (icon.includes("keyboard"))   return md(0xf030c); // md-keyboard
        if (icon.includes("phone"))      return md(0xf011c); // md-cellphone
        if (icon.includes("watch"))      return md(0xf0589); // md-watch
        if (icon.includes("computer") || icon.includes("laptop"))
            return md(0xf0322);                              // md-laptop
        if (icon.includes("gaming") || icon.includes("joypad"))
            return md(0xf0297);                              // md-gamepad-variant
        return md(0xf00af);                                  // md-bluetooth
    }

    Rectangle {
        anchors.fill: parent
        color: !row.device.connected && rowHover.hovered
            ? Qt.alpha(Theme.background, 0.10) : "transparent"

        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    Frame {
        anchors.fill: parent
        shown: row.device.connected
    }

    HoverHandler { id: rowHover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        Text {
            text: row.glyph
            color: row.device.connected ? Theme.primary : Qt.alpha(Theme.background, 0.75)
            font.family: Theme.iconFont
            font.pixelSize: Tokens.fontSize.normal

            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.spacing.extraSmall
            text: row.device.deviceName || row.device.name || row.device.address
            elide: Text.ElideRight
            color: row.device.connected ? Theme.primary : Theme.background
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small
        }

        Text {
            visible: row.device.connected && row.device.batteryAvailable
            text: Math.round(row.device.battery * 100) + "%"
            color: row.device.battery < 0.2 ? Theme.hot : Qt.alpha(Theme.primary, 0.8)
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small
        }

        Text {
            id: link
            text: String.fromCodePoint(row.device.connected ? 0xf0338 : 0xf0337)
            color: row.busy ? Theme.warm
                 : row.device.connected ? Theme.primary
                 : (connectHover.hovered ? Theme.background : Qt.alpha(Theme.background, 0.6))
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

            HoverHandler { id: connectHover }
            TapHandler {
                enabled: !row.busy
                onTapped: {
                    if (!row.known) row.device.pair();
                    else if (row.device.connected) row.device.disconnect();
                    else row.device.connect();
                }
            }
        }

        Text {
            // Only bonded devices can be forgotten.
            visible: row.device.bonded
            text: "×"
            color: forgetHover.hovered ? Theme.hot
                 : Qt.alpha(row.device.connected ? Theme.primary : Theme.background, 0.6)
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.larger
            leftPadding: Tokens.spacing.extraSmall

            Behavior on color { CAnim { motion: Motion.fastEffect } }

            HoverHandler { id: forgetHover }
            TapHandler { onTapped: row.device.forget() }
        }
    }
}
