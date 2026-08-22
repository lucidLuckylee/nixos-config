// One Bluetooth device, as a row in the menu's list.
//
// Contents are caelestia's — class icon, name, battery, connect, forget — but
// stripped of the Material furniture they sit in over there. No filled circular
// button behind the connect icon, no icon for delete: a lit 2px bar at the
// left says connected, and the two actions are bare glyphs that brighten under
// the pointer. On a desktop whose entire visual language is hairlines and
// monospace, a solid disc is the loudest thing on screen, and it was being
// spent on the least surprising control in the menu.
//
// Battery is a number rather than one of the eleven battery glyphs: "82%" is
// smaller than the glyph, exact, and already in the font everything else is set
// in. It is the one reading on the row, and the device's name is the only other
// text — everything that can be a symbol is one.
//
// Everything is drawn in the dark colour, because the row sits on the menu's
// accent-coloured host. Which means "connected" cannot be signalled with the
// accent the way it is everywhere else on this desktop — the whole ground is
// already that colour — so a connected row is the one that goes *solid*: a dark
// slab with the accent showing through its text.

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

Item {
    id: row

    required property BluetoothDevice device

    // Milliseconds to wait before this row arrives, so a list assembles in
    // sequence rather than all at once. Set from the delegate's index.
    property int entryDelay: 0

    readonly property bool known: device.paired || device.bonded
    readonly property bool busy: device.pairing
        || device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting

    implicitHeight: 30

    // The entry. Theirs scales from 0.7 as it fades in, and the scale rides the
    // spatial curve so each row springs into place — which is where most of the
    // "fluid" impression in that shell actually comes from. The whole menu is
    // rebuilt on every open (see the Loader in BluetoothFlyout.qml), so this
    // plays each time it is opened rather than once per session.
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

    // BlueZ reports an icon name from the freedesktop set. Only the handful of
    // classes that actually turn up on a desk are mapped; anything else — and
    // anything BlueZ declines to classify — falls back to the Bluetooth rune,
    // which is never wrong, only unspecific.
    //
    // Written as codepoints rather than pasted glyphs: these live in the Nerd
    // Font private use area, where a literal is an unreadable box in every
    // editor and diff, and one silently swapped character is unfindable.
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

    // The connected marker: the row itself, filled. Inverting the inversion is
    // the only move left that reads at a glance on an accent-coloured ground.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.small
        color: row.device.connected
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

        // ── Connect ─────────────────────────────────────────────────────
        // md-link-off once connected, because the button's job is then to undo
        // that. Doubles as the pair action for a device that has never been
        // paired — from here they are the same intent.
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

            // Pairing and connecting take seconds and can fail, so something has
            // to say the row is mid-flight. It used to say so in words —
            // "connecting…" — which on a two-column menu was the longest thing
            // on the row. The glyph breathing says the same and costs no width.
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

        // ── Forget ──────────────────────────────────────────────────────
        // Only for devices actually bonded to this machine — forgetting one
        // that merely turned up in a scan does nothing, so there is nothing to
        // press. A plain × rather than a bin glyph: it is the same character the
        // rest of the desktop closes things with. The one place red is used
        // inside this menu, since on the bar red is simply what text is.
        Text {
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
