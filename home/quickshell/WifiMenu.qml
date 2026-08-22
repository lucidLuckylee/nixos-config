// The wifi menu.
//
// The second thing built on Chrome.qml, and deliberately the same exercise as
// BluetoothFlyout.qml: say how big the contents are, how big they can get, and
// what they are. Everything else — the shape, the placement, the reveal — is the
// chrome's, and none of it appears here.
//
// It is close enough to the Bluetooth menu to be read side by side, and where it
// differs it differs because wifi is not Bluetooth: one column instead of two,
// because an SSID is a sentence and a device name is a word; a signal reading on
// every row rather than a battery on the connected one, because signal is the
// only thing that distinguishes two networks you can equally well join.

import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "wifi"

    // The first wifi interface, the same way Bar.qml finds it. A machine with two
    // is rare enough that picking one and getting it wrong is a better failure
    // than a device selector on a menu this small.
    readonly property var device: {
        const devices = Networking.devices.values;
        return devices.find(d => d.type === DeviceType.Wifi) ?? null;
    }

    readonly property bool live: device !== null && Networking.wifiEnabled

    readonly property int gap: Tokens.spacing.small
    readonly property int headerHeight: 22
    readonly property int rowHeight: 30

    // Five, where Bluetooth allows six in two columns. The counts are alike but
    // the reasons are not: a desk has a bounded number of paired devices and an
    // unbounded number of neighbours' access points, so this cap is not a
    // pathological case, it is the normal one — in a flat the scan finds thirty.
    // The five strongest are the five that could plausibly be joined.
    readonly property int maxRows: 5

    // No list at all with the radio off — that is what lets the menu collapse to
    // a nudge with a single button on it rather than sit there full-size holding
    // an apology.
    readonly property int rows: live ? Math.min(maxRows, Math.max(1, networks.length)) : 0

    // What Chrome needs: the size now and the size at worst. Ordinary bindings,
    // so a scan finding one more network animates the menu open a little further
    // on its own.
    //
    // Narrower than the Bluetooth menu despite being taller: one column of SSIDs
    // needs about half the width of two columns of device names, and a menu wider
    // than its contents reads as a menu with something missing from it.
    contentWidth: live ? 300 : 26
    contentHeight: headerHeight + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + maxRows * (rowHeight + gap) - gap

    // NetworkManager reports signal strength as a percentage and other backends
    // report a fraction; both arrive as a double, so anything above 1 is read as
    // the percentage it already is. Same normalisation the bar does — it has to
    // be, or the pill and the menu disagree about the network they both name.
    function normalised(raw) {
        return raw > 1 ? raw / 100 : raw;
    }

    // ── The network list ────────────────────────────────────────────────
    // Out here rather than inside the list, because the menu's own height is
    // derived from how long it is.
    //
    // Connected first, then remembered, then by strength, then by name. Note what
    // this binding depends on: the *set* of networks, not their signal strengths.
    // Strength is read inside the comparator, so the order is settled when the
    // scan result changes and then left alone — a list that reshuffled every time
    // two neighbours' access points traded a decibel would be impossible to click.
    //
    // Nameless entries are dropped. A hidden SSID comes through with an empty
    // name, and a blank row that cannot be identified is not a row anyone can act
    // on; joining one takes typing the name in, which this menu has no way to do.
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

        // The header. No title and no count, for the reason the Bluetooth menu has
        // neither: the pill this grew out of is directly above and already says
        // which menu it is, and the networks are right there to be counted.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            Chip {
                id: radio

                // Pinned to `pillAnchor` rather than to an edge of the box —
                // see Chrome.qml. This is what makes the collapse work:
                // switching the radio off shrinks the menu to almost nothing
                // around a button that has not moved, instead of sliding the
                // button across a box travelling the other way.
                //
                // No Behavior on x, deliberately — the anchor is in the content's
                // coordinates, and while the menu resizes the content moves and
                // shrinks underneath this chip, so its local x must change every
                // frame precisely to stay still on screen. Animating that makes it
                // lag the correction and slide out from under the pointer that just
                // clicked it.
                x: Math.max(0, Math.min(parent.width - width, menu.pillAnchor))
                anchors.verticalCenter: parent.verticalCenter

                glyph: String.fromCodePoint(
                    menu.live ? 0xf05a9    // md-wifi
                              : 0xf05aa)   // md-wifi-off
                active: menu.live

                // The hardware kill switch is a separate veto from the software
                // one: with rfkill closed, writing `wifiEnabled` is accepted and
                // then quietly undone. Greyed out rather than hidden, because
                // unlike the scan chip below this is the control the menu is
                // *for*, and a menu that empties itself explains nothing.
                available: menu.device !== null && Networking.wifiHardwareEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            // Rescan, to the radio chip's left so the header grows away from the
            // pill. Quickshell only asks the backend to sweep while something is
            // listening, so without this the list is whatever NetworkManager last
            // happened to see; with it on, it is what is actually in the air.
            //
            // Gone entirely with the radio off rather than present and greyed: the
            // collapsed menu is meant to be one button, and a second one that
            // cannot be pressed is just something else to look at.
            Chip {
                x: radio.x - width - Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter

                // Fades rather than vanishing. The menu resizes over 350ms, and a
                // control that disappears in one frame of that makes the whole
                // thing read as being swapped for a smaller menu instead of
                // shrinking into one.
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

        // The networks, in a Loader keyed on the radio being on, for two reasons:
        // with it off there is nothing here at all, which is what lets the menu
        // collapse; and switching it back on rebuilds the list, so the rows scale
        // in exactly as they do when the menu is first opened.
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Fades out, then unloads — `active` outlives `live` for exactly as
            // long as the fade. Unloading on the spot makes switching the radio off
            // look like a replacement rather than a collapse: the rows blink out in
            // one frame while the box is still most of a resize away from its new
            // size.
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

                // ── One network ─────────────────────────────────────────
                // Built the way DeviceRow.qml is, and for the same reason: the row
                // stands on the menu's accent-coloured host, so everything on it is
                // drawn in the dark colour, and "connected" cannot be signalled
                // with the accent because the accent is already the ground. The
                // connected row is the one that goes solid instead — a dark slab
                // with the accent showing through its text.
                //
                // Written out here rather than factored into a NetworkRow.qml
                // beside DeviceRow.qml: the two look alike but share no property,
                // and a common row type would be a parameter list longer than
                // either of them.
                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property real strength: menu.normalised(modelData.signalStrength)

                    // Association takes seconds and can fail. The backend says so
                    // itself, which is better than inferring it from the state
                    // enum — `stateChanging` covers connecting and disconnecting
                    // alike, and both are the same "wait" to the person watching.
                    readonly property bool busy: modelData.stateChanging

                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.rowHeight

                    // The entry, staggered off the index so the list assembles in
                    // sequence rather than arriving all at once. The whole list is
                    // rebuilt on every open (see the Loader above), so this plays
                    // each time the menu is opened rather than once per session.
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

                        // The strength, as the bar's own four-bar ladder rather
                        // than as a second copy of the percentage beside it. The
                        // same glyph the pill is showing for the connected network
                        // appears on the connected row, which is what ties the two
                        // together at a glance.
                        //
                        // Codepoints rather than pasted glyphs: these live in the
                        // Nerd Font private use area, where a literal is an
                        // unreadable box in every editor and diff.
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
                            // Remembered networks are set solid and the rest are
                            // dimmed, so the ones this machine can actually join
                            // without being asked for anything read first. It is
                            // the only distinction between rows the glyphs do not
                            // already make.
                            color: row.modelData.connected
                                ? Theme.primary
                                : Qt.alpha(Theme.background, row.modelData.known ? 1 : 0.7)
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }

                        // The number as well as the ladder, because the ladder has
                        // four steps and choosing between two networks in the same
                        // step is exactly when the difference matters.
                        Text {
                            text: Math.round(row.strength * 100) + "%"
                            color: row.modelData.connected
                                ? Qt.alpha(Theme.primary, 0.8)
                                : Qt.alpha(Theme.background, 0.6)
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }

                        // ── Join / leave ────────────────────────────────
                        // md-link-off once connected, because the button's job is
                        // then to undo what it did. The same pair DeviceRow uses,
                        // so the action sits in the same place and looks the same
                        // on both menus.
                        //
                        // A network this machine has never seen gets the same
                        // press: `connect()` is the whole of it. An open network
                        // joins, a secured one fails and stays where it is —
                        // asking for a passphrase would mean taking the keyboard,
                        // which these menus deliberately never do (see Chrome.qml).
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

                            // Something has to say the row is mid-flight, and the
                            // glyph breathing says it without costing the width a
                            // word like "connecting…" would take out of the SSID.
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
                                onTapped: {
                                    if (row.modelData.connected) row.modelData.disconnect();
                                    else row.modelData.connect();
                                }
                            }
                        }
                    }
                }
            }

            // Sits in the row the arithmetic above already reserved, so a radio
            // that has found nothing is not a differently sized menu.
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.rowHeight
                verticalAlignment: Text.AlignVCenter
                visible: menu.networks.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small
                // The only text on the menu that is not an SSID. An empty list
                // cannot explain itself with a symbol, and it is the one moment
                // where there is nothing else to look at anyway.
                text: menu.device && menu.device.scannerEnabled
                    ? "scanning…" : "no networks"
            }

            Item { Layout.fillHeight: true }
        }
    }
}
