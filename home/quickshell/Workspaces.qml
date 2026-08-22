// The workspace strip at the left end of the bar.
//
// Sway is i3-compatible down to the IPC socket, so Quickshell's I3 module is
// the sway module: `I3.workspaces` is the live list and `I3.dispatch` sends
// commands back. Only the workspaces on *this* bar's monitor are shown, which
// is what swaybar did and what makes a two-screen desk readable.
//
// The focused chip is not drawn per chip. There is one highlight rectangle
// that moves to wherever the focused chip is, so switching workspaces slides
// the neon across the strip instead of blinking it out in one place and into
// another. That is the whole reason this is a Repeater over a Row rather than
// a ListView: the chips have to hold still and be measurable while the one
// moving thing moves.

import QtQuick
import Quickshell.I3

Item {
    id: root

    required property string monitor

    implicitWidth: chips.width

    // Numbered workspaces first, in order, then the named ones in the order
    // ../workspaces.nix lists them.
    //
    // Sorting on `num` alone does not do this: sway gives a named workspace a
    // number of -1, so Firefox and Telegram would sort ahead of workspace 1,
    // and between themselves they would come out in whichever order they were
    // first opened in — which changes from login to login.
    function rank(ws) {
        if (ws.num > 0) return ws.num;

        const known = Session.namedWorkspaces.indexOf(ws.name);
        // Named and listed: after every number, in the listed order. Named and
        // unlisted: after those, in sway's order, which Array.sort leaves
        // alone because it is stable.
        return known >= 0 ? 1000 + known : 2000;
    }

    readonly property var shown: I3.workspaces.values
        .filter(ws => ws.monitor && ws.monitor.name === root.monitor)
        .sort((a, b) => root.rank(a) - root.rank(b))

    // The chip the highlight is currently parked on. Null while the focus is
    // on another monitor, which is when the highlight fades out rather than
    // sliding to a corner.
    property Item focusedChip: null

    // Square at the bottom and rounded at the top, running the full height of
    // the bar: a tab the focused window hangs from rather than a chip floating
    // in a strip. The bottom edge deliberately covers the bar's hairline,
    // which is what makes the two read as joined.
    Rectangle {
        id: highlight
        topLeftRadius: 2
        topRightRadius: 2
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: Theme.primary
        opacity: root.focusedChip ? 1 : 0
        height: parent.height
        y: 0

        x: root.focusedChip ? root.focusedChip.x : x
        width: root.focusedChip ? root.focusedChip.width : width

        // The most-seen motion in the shell, so it gets the spatial treatment:
        // the tab overshoots the chip it is travelling to and settles back
        // into it. Width rides the same curve, which is what keeps the two
        // edges of a tab that is also changing size from arriving separately.
        Behavior on x { Anim { motion: Motion.fastSpatial } }
        Behavior on width { Anim { motion: Motion.fastSpatial } }

        // Fading is not travelling, so it does not overshoot.
        Behavior on opacity { Anim { motion: Motion.fastEffect } }
    }

    Row {
        id: chips
        height: parent.height
        spacing: 4

        Repeater {
            model: root.shown

            Item {
                id: chip
                required property var modelData

                width: Math.max(24, text.implicitWidth + 14)
                height: parent.height

                // The highlight is a sibling drawn underneath, so the chip
                // tells the strip where it is rather than drawing its own
                // background. Re-reported on any geometry change, because the
                // strip reflows whenever a workspace appears or disappears.
                function claim() {
                    if (modelData.focused) root.focusedChip = chip;
                }
                Component.onCompleted: claim()
                onXChanged: claim()
                onWidthChanged: claim()

                Connections {
                    target: chip.modelData
                    function onFocusedChanged() { chip.claim(); }
                }

                // Urgent is the one state that outranks the sliding highlight:
                // it has to be visible on the monitor you are *not* looking at.
                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: 2
                    topRightRadius: 2
                    color: Theme.warm
                    visible: chip.modelData.urgent && !chip.modelData.focused
                }

                Text {
                    id: text
                    anchors.centerIn: parent
                    text: chip.modelData.name
                    // The workspace names in the sway config are themselves
                    // Nerd Font glyphs, so this cannot be the plain family.
                    font.family: Theme.iconFont
                    // Larger than the readouts on the other end: these are the
                    // one thing on the bar that is navigated by, not read.
                    font.pixelSize: 13
                    // Red like the readouts at the other end of the bar, except
                    // where the chip itself is filled: on the cyan focus tab
                    // and the amber urgent one the label inverts to the
                    // background instead.
                    color: {
                        if (chip.modelData.focused || chip.modelData.urgent)
                            return Theme.background;
                        return Theme.hot;
                    }
                    opacity: chip.modelData.focused || chip.modelData.active ? 1 : 0.75

                    Behavior on color { CAnim { motion: Motion.fastEffect } }
                }

                TapHandler {
                    onTapped: I3.dispatch("workspace " + chip.modelData.name)
                }
            }
        }
    }
}
