// The Bluetooth menu.
//
// All of the shape, placement and reveal live in Chrome.qml — this file is only
// what is inside one: the two adapter chips, and the devices. A wifi or volume or
// calendar menu is the same exercise, and should be the same three declarations:
// how big its contents are, how big they can get, and what they are.
//
// Contents follow caelestia-dots/shell's Bluetooth popout
// (modules/bar/popouts/Bluetooth.qml): the two adapter settings, and the devices
// sorted connected-then-paired-then-name with a connect action and a forget
// action each. Their per-row entry animation is theirs too. The chrome is not —
// see Chrome.qml.

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

    // Two columns of three, which is more devices than a desk has. A menu that
    // grew to fill the screen because a scan found eleven phones would be worse
    // than one that stops.
    readonly property int maxRows: 3

    // No device area at all with the adapter off — that is what collapses the menu
    // to a nudge with one button on it rather than a menu with an apology in it.
    readonly property int rows: live
        ? Math.min(maxRows, Math.max(1, Math.ceil(devices.length / columns)))
        : 0

    // What Chrome needs: the size now, and the size at worst. Both are ordinary
    // bindings, so switching the adapter on or finding a device animates the menu
    // open a little further of its own accord.
    contentWidth: live ? 480 : 26
    contentHeight: headerHeight
        + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + maxRows * (rowHeight + gap) - gap

    // ── The device list ─────────────────────────────────────────────────
    // Computed out here rather than inside the list, because the menu's own size
    // depends on how long it is.
    //
    // Sorted connected first, then paired, then by name — caelestia's comparator
    // exactly. Sorting on connectedness is safe in a list of rows in a way it
    // would not be in a grid of tiles: the row that moves when you connect
    // something is the row you just clicked, and it moves to the top, where you
    // are already looking.
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

        // The two adapter chips. There is no title, because the pill this grew
        // out of is directly above it and already says which menu it is; and no
        // line counting the devices, because the devices are right there.
        //
        // The power chip is pinned directly under the pill rather than aligned to
        // an edge, and that is what makes the collapse work: switching Bluetooth
        // off shrinks the menu to almost nothing around a button that has not
        // moved, instead of sliding the button from one end of the menu to the
        // middle of a smaller one while the box travels the other way.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            Chip {
                id: power

                // Hung from `pillAnchor` — see Chrome.qml. This is the one
                // position that both the open menu and the collapsed column
                // agree on, so toggling the adapter shrinks the menu around a
                // chip that does not move.
                x: Math.max(0, Math.min(parent.width - width, menu.pillAnchor))
                anchors.verticalCenter: parent.verticalCenter

                glyph: String.fromCodePoint(
                    menu.live ? 0xf00af    // md-bluetooth
                              : 0xf00b2)   // md-bluetooth-off
                active: menu.live
                available: menu.adapter !== null
                onToggled: menu.adapter.enabled = !menu.adapter.enabled

                // No Behavior on x, deliberately — the same trap as the body's
                // position in Chrome.qml. The anchor is in the *content's*
                // coordinates, and while the menu resizes the content moves and
                // shrinks underneath this chip, so its local x has to change every
                // frame precisely to stay still on screen. Animating it makes it
                // lag that correction, and the button visibly slides out from under
                // the pointer that just clicked it.
            }

            // Scan, to the power chip's left so it grows away from the pill.
            // Gone entirely with the adapter off rather than present and greyed:
            // the collapsed menu is meant to be one button, and a second one that
            // cannot be pressed is just something else to look at.
            Chip {
                x: power.x - width - Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                // Fades rather than vanishing. The menu resizes over 350ms, and a
                // control that disappears in one frame of that makes the whole
                // thing read as being swapped for a smaller menu instead of
                // shrinking into one.
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

        // The devices, in a Loader keyed on the adapter being on, for two reasons:
        // with it off there is nothing here at all, which is what lets the menu
        // collapse; and switching it on rebuilds the list, so the rows scale in
        // exactly as they do when the menu is first opened. Same reveal either way.
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Fades out, then unloads — `active` outlives `live` for exactly as
            // long as the fade. Unloading on the spot is what made switching
            // Bluetooth off look like a replacement: the rows blinked out in a
            // single frame while the box was still 300px into its resize.
            //
            // It does still unload, which is what replays the rows' stagger the
            // next time the adapter comes on.
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

            // Sits in the row the arithmetic already reserved, so an adapter with
            // nothing paired does not change the menu's height.
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.rowHeight
                verticalAlignment: Text.AlignVCenter
                visible: menu.devices.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small
                // The only text on the menu that is not a device's name. An empty
                // list cannot explain itself with a symbol, and it is the one
                // moment where there is nothing else to look at anyway.
                text: menu.adapter && menu.adapter.discovering
                    ? "scanning…" : "no devices"
            }

            Item { Layout.fillHeight: true }
        }
    }
}
