// Bluetooth device status with pairing, connection and forget actions.

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

MenuRow {
    id: row

    required property BluetoothDevice device

    readonly property bool known: device.paired || device.bonded
    readonly property bool busy: device.pairing
        || device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting

    current: device.connected

    readonly property string glyph: {
        const icon = device.icon || "";
        const md = Status.md;
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

    Icon {
        text: row.glyph
        color: row.current ? Theme.primary : Qt.alpha(Theme.background, 0.75)
        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.spacing.extraSmall
        text: Status.deviceName(row.device)
        elide: Text.ElideRight
        color: row.current ? Theme.primary : Theme.background
    }

    Label {
        visible: row.current && row.device.batteryAvailable
        text: Math.round(row.device.battery * 100) + "%"
        color: row.device.battery < 0.2 ? Theme.hot : Qt.alpha(Theme.primary, 0.8)
    }

    LinkButton {
        connected: row.current
        busy: row.busy
        onClicked: {
            if (!row.known) row.device.pair();
            else if (row.device.connected) row.device.disconnect();
            else row.device.connect();
        }
    }

    // Only bonded devices can be forgotten.
    Label {
        visible: row.device.bonded
        text: "×"
        color: forgetHover.hovered ? Theme.hot
             : Qt.alpha(row.current ? Theme.primary : Theme.background, 0.6)
        font.pixelSize: Tokens.fontSize.larger
        rightPadding: Tokens.spacing.extraSmall

        Behavior on color { CAnim { motion: Motion.fastEffect } }

        HoverHandler {
            id: forgetHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler { onTapped: row.device.forget() }
    }
}
