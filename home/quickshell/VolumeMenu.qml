// The volume menu.
//
// A MenuPage inside the single menu window: the shape, the placement and the
// reveal are all Chrome.qml's, and what is here is only the three
// declarations a page owes it — how big its contents are, how big they can
// get, and what they are.
//
// Contents are the sound controls that the bar's volume pill can only report on:
// the default output's level as something draggable, a mute chip, and the list of
// outputs to move the default between. Nothing else. A per-application mixer and
// an input level both belong to sound, and both would turn a menu that answers
// "make it quieter" into one that has to be read first.
//
// Everything is drawn inverted — dark ink on the accent-coloured host — for the
// reason set out in Chrome.qml. See Chip.qml and DeviceRow.qml, which the
// controls here are built to match.

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "volume"

    // ── What is being controlled ────────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink ? sink.audio : null

    readonly property real level: audio ? audio.volume : 0
    readonly property bool muted: audio !== null && audio.muted

    // Every output PipeWire knows about. `isStream` excludes the nodes that
    // *play into* a sink — an application's playback stream is a sink in the
    // graph's sense and would otherwise turn up here as a device you could
    // switch to. `audio` excludes anything that is a sink but not a sound one;
    // it is a constant property, decided when the node appears, so testing it
    // does not need the node tracked first.
    //
    // Sorted current-first, then by name. The sort does two things: it puts the
    // row you just clicked at the top, where you are already looking — the same
    // argument as the Bluetooth list's comparator — and it guarantees the
    // current output survives the cap below, which sorting by name alone would
    // not.
    readonly property var outputs: {
        return Pipewire.nodes.values
            .filter(n => n.isSink && !n.isStream && n.audio)
            .sort((a, b) =>
                ((b === menu.sink) - (a === menu.sink))
                || menu.outputName(a).localeCompare(menu.outputName(b))
            )
            .slice(0, maxRows);
    }

    // A node's `audio` holds stub values until something tracks it, so the
    // volume would read as zero and refuse to be set without this. The default
    // sink is unioned in rather than assumed to be in the list: it is only in
    // `outputs` if it passed the filter above, and a menu that silently stopped
    // controlling the volume because a node failed a predicate is worse than one
    // that tracks the same object twice.
    PwObjectTracker {
        objects: menu.sink && !menu.outputs.includes(menu.sink)
            ? [menu.sink, ...menu.outputs]
            : menu.outputs
    }

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property int gap: Tokens.spacing.small
    readonly property int headerHeight: 22
    readonly property int trackHeight: 22

    // Shorter than the Bluetooth list's 30px rows, which carry two actions and a
    // battery reading on the right. These carry a glyph and a name, and the row
    // is the button, so there is nothing for the extra height to hold.
    readonly property int rowHeight: 26
    readonly property int maxRows: 4

    // A list of one is not a choice. With a single output the whole section goes
    // away and the menu is the level and the mute chip, which is what it is on a
    // machine with nothing plugged into it.
    readonly property int rows: outputs.length > 1 ? outputs.length : 0

    // Wide enough that "Family 17h/19h HD Audio Controller Analog Stereo" is
    // still recognisable after eliding, and no wider — the level control is the
    // reason to open this, and a slider two thirds the width of the screen
    // implies a precision the volume does not have.
    readonly property int naturalWidth: 320

    contentWidth: naturalWidth
    contentHeight: headerHeight + gap + trackHeight
        + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + trackHeight
        + gap + maxRows * (rowHeight + gap) - gap

    // Prefer the short name PipeWire keeps for exactly this purpose; fall back
    // to the long one, and to the node's own name, which is an identifier rather
    // than a label and is only ever a last resort.
    function outputName(node) {
        return node.nickname || node.description || node.name;
    }

    // The only distinction worth drawing is where the sound is going: to
    // something on your head, to a screen, or to the machine. BlueZ and ALSA
    // both put that in the node's name, and anything finer would be a guess
    // dressed up as an icon.
    function outputGlyph(node) {
        const name = (node.name || "").toLowerCase();
        if (name.startsWith("bluez"))
            return String.fromCodePoint(0xf02cb);  // md-headphones
        if (name.includes("hdmi") || name.includes("displayport"))
            return String.fromCodePoint(0xf0379);  // md-monitor
        return String.fromCodePoint(0xf04c3);      // md-speaker
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        // ── The reading, and mute ───────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            // The one number on the menu, so it is set larger than anything
            // else here. It is also the only thing that says what the level bar
            // below it means, which is why it is a percentage and not a glyph.
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                // Brackets around the number when muted, exactly as the pill
                // this menu hangs from writes it (see Bar.qml). They say the
                // same thing there and here: the level is still set, it is
                // simply not coming out — which is also why dragging works
                // while muted.
                text: {
                    if (!menu.audio) return "--";
                    const percent = Math.round(menu.level * 100) + "%";
                    return menu.muted ? "(" + percent + ")" : percent;
                }
                color: Qt.alpha(Theme.background, menu.muted ? 0.6 : 1)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.larger

                Behavior on color { CAnim { motion: Motion.fastEffect } }
            }

            // Pinned under the pill rather than to an edge of the box, for the
            // reason set out on `pillRight` in Chrome.qml: it is the control
            // the pill stands for, and it should be under the pointer that just
            // arrived from it. The right-edge anchor matters here too — muting
            // puts brackets around the pill's label, which grows the pill at
            // exactly the moment this chip is clicked.
            //
            // No Behavior on x — see the same chip in BluetoothFlyout.qml. The
            // anchor is in the content's coordinates and has to change every
            // frame while the menu resizes, precisely to keep this still.
            Chip {
                x: Math.max(0, Math.min(parent.width - width,
                                        menu.pillRight - width - menu.pad))
                anchors.verticalCenter: parent.verticalCenter

                // The pill's own ladder, copied deliberately: the chip is
                // directly below the glyph it is echoing, and the two showing
                // different symbols for one state would read as two different
                // readings rather than one.
                glyph: {
                    if (!menu.audio || menu.muted)
                        return String.fromCodePoint(0xf075f);  // md-volume-mute
                    if (menu.level > 0.5)
                        return String.fromCodePoint(0xf057e);  // md-volume-high
                    if (menu.level > 0)
                        return String.fromCodePoint(0xf0580);  // md-volume-medium
                    return String.fromCodePoint(0xf057f);      // md-volume-low
                }
                active: menu.muted
                available: menu.audio !== null
                onToggled: menu.audio.muted = !menu.audio.muted
            }
        }

        // ── The level ───────────────────────────────────────────────────
        // A hairline box that fills from the left, in the same two states
        // everything else on this menu has: outlined, or solid. It is the same
        // move DeviceRow makes for a connected device — on an accent-coloured
        // ground the only thing louder than an outline is a fill — and it means
        // the slider needs no knob, because the edge of the fill is the knob.
        Item {
            id: level

            Layout.fillWidth: true
            Layout.preferredHeight: menu.trackHeight

            // Clamped for drawing only. PipeWire will happily report a volume
            // above 1.0 — that is software gain, and something else on the
            // system may well have set it — and a fill wider than its track
            // would paint over the menu's padding.
            readonly property real fraction: Math.max(0, Math.min(1, menu.level))

            // The track is what the pointer is measured against, so the
            // arithmetic converting a position back into a volume lives with it.
            // The 1px inset on each side is the hairline: the fill sits inside
            // the border rather than under it, so dragging to either end lands
            // on exactly 0 and exactly 1 instead of a pixel short.
            function setFrom(x) {
                if (!menu.audio) return;
                const span = Math.max(1, width - 2);
                // Capped at 1.0 rather than following PipeWire's ceiling. Above
                // unity is amplification, and a control that reaches it by
                // being dragged one pixel too far is a control that distorts
                // your headphones by accident.
                menu.audio.volume = Math.max(0, Math.min(1, (x - 1) / span));
            }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.rounding.extraSmall
                color: "transparent"
                border.width: 1

                // Brightens under the pointer and stays bright while held, so
                // the box reads as something to grab rather than as a gauge.
                border.color: Qt.alpha(Theme.background,
                    grab.containsMouse || grab.pressed ? 0.8 : 0.45)

                Behavior on border.color { CAnim { motion: Motion.fastEffect } }

                Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: Math.round((parent.width - 2) * level.fraction)

                    // Rounded where it meets the track's corners, square where
                    // it stops. That square edge is the whole readout: a
                    // rounded one has no single position, so the level would be
                    // legible to within a couple of pixels at best.
                    topLeftRadius: Tokens.rounding.extraSmall - 1
                    bottomLeftRadius: Tokens.rounding.extraSmall - 1
                    topRightRadius: 0
                    bottomRightRadius: 0

                    // Dimmed rather than emptied when muted. The level has not
                    // gone anywhere — it is what the sound comes back to — and
                    // an empty track would say it had been turned down to zero.
                    color: Qt.alpha(Theme.background, menu.muted ? 0.3 : 1)

                    Behavior on color { CAnim { motion: Motion.fastEffect } }

                    // Animated when the volume changes from somewhere else —
                    // the volume keys, a mixer — and never while it is being
                    // dragged. A 150ms ease behind the pointer is small enough
                    // to look like input lag rather than like motion, and it is
                    // exactly the wrong 150ms to add to a direct manipulation.
                    Behavior on width {
                        enabled: !grab.pressed
                        Anim { motion: Motion.fastEffect }
                    }
                }
            }

            // A MouseArea rather than a DragHandler, which is the exception to
            // this shell's use of handlers everywhere else. A DragHandler does
            // not activate until the pointer has moved past the drag threshold,
            // so the first several pixels of every drag would do nothing and
            // the level would then jump to catch up. Here the press *is* the
            // gesture: pressing anywhere on the track sets the level there, and
            // moving carries on setting it.
            //
            // No keyboard anything, deliberately: these surfaces take no
            // keyboard focus (see Bar.qml), so a control that could only be
            // reached by tabbing to it could not be reached at all.
            MouseArea {
                id: grab
                anchors.fill: parent
                hoverEnabled: true
                enabled: menu.audio !== null

                onPressed: event => level.setFrom(event.x)
                onPositionChanged: event => {
                    if (pressed) level.setFrom(event.x);
                }
            }
        }

        // ── The outputs ─────────────────────────────────────────────────
        // Gone entirely when there is only one, rather than shown with the one
        // row lit: a list that cannot be chosen from is a readout, and the menu
        // already has one of those at the top.
        //
        // No entry stagger on these rows, unlike the Bluetooth list's. Nothing
        // here is created when the menu opens — the list is built once and lives
        // as long as the shell does — so an animation keyed on creation would
        // play at login, to nobody, and never again.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: menu.gap
            visible: menu.rows > 0

            Repeater {
                model: menu.outputs

                Item {
                    id: row

                    required property var modelData
                    readonly property bool current: modelData === menu.sink

                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.rowHeight

                    // Solid for the output currently in use — DeviceRow's marker
                    // for a connected device, for the same reason it is used
                    // there: the accent is the ground here, so it cannot also be
                    // the highlight, and inverting the inversion is what is left.
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        color: row.current
                            ? Theme.background
                            : (hover.hovered ? Qt.alpha(Theme.background, 0.10) : "transparent")

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    HoverHandler { id: hover }

                    // The whole row is the button — there is one thing to do to
                    // an output you are not using, and a separate glyph to press
                    // would only make the row harder to hit.
                    //
                    // `preferredDefaultAudioSink` rather than any of the
                    // read-only defaults: it is the configured preference, so
                    // the choice survives the sink disappearing and coming back.
                    TapHandler {
                        enabled: !row.current
                        onTapped: Pipewire.preferredDefaultAudioSink = row.modelData
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.spacing.medium
                        spacing: Tokens.spacing.small

                        Text {
                            text: menu.outputGlyph(row.modelData)
                            color: row.current ? Theme.primary : Qt.alpha(Theme.background, 0.75)
                            font.family: Theme.iconFont
                            font.pixelSize: Tokens.fontSize.normal

                            Behavior on color { CAnim { motion: Motion.fastEffect } }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.spacing.extraSmall
                            text: menu.outputName(row.modelData)
                            // Elided in the middle rather than at the end, which
                            // is the one place this diverges from DeviceRow. Two
                            // outputs on the same card differ only in their last
                            // few words — "Analog Stereo" against "HDMI 2" — so
                            // cutting the tail off is cutting off the only part
                            // that tells the rows apart.
                            elide: Text.ElideMiddle
                            color: row.current ? Theme.primary : Theme.background
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }
                    }
                }
            }

            // Holds the bottom of the column down while the list is shorter than
            // the room the arithmetic reserved for it.
            Item { Layout.fillHeight: true }
        }
    }
}
