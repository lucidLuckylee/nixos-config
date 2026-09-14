// Workspaces for one monitor, with a shared sliding focus highlight.

import QtQuick
import Quickshell.I3

Item {
    id: root

    required property string monitor

    implicitWidth: chips.width

    // Numbered workspaces come first, followed by the configured named order.
    function rank(ws) {
        if (ws.num > 0) return ws.num;

        const known = Session.namedWorkspaces.indexOf(ws.name);
        return known >= 0 ? 1000 + known : 2000;
    }

    readonly property var shown: I3.workspaces.values
        .filter(ws => ws.monitor && ws.monitor.name === root.monitor)
        .sort((a, b) => root.rank(a) - root.rank(b))

    property Item focusedChip: null

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

        Behavior on x { Anim { motion: Motion.fastSpatial } }
        Behavior on width { Anim { motion: Motion.fastSpatial } }

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

                // Refresh the highlight after layout changes as well as focus changes.
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
                    font.family: Theme.iconFont
                    font.pixelSize: 13
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
