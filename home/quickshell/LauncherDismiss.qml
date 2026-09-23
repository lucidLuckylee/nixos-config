// While the launcher is open, an invisible layer over the whole screen, bar
// included, turns any click into closing it without running anything. Clicks
// inside `hole`, the launcher itself, pass through to it.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: dismiss

    property var modelData
    screen: modelData

    property rect hole

    visible: Launcher.open

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        width: dismiss.width
        height: dismiss.height

        Region {
            intersection: Intersection.Subtract
            x: dismiss.hole.x
            y: dismiss.hole.y
            width: dismiss.hole.width
            height: dismiss.hole.height
        }
    }

    WlrLayershell.namespace: "holo-launcher-dismiss"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Launcher.open = false
    }
}
