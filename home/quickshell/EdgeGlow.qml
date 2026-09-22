// A faint primary glow along the left, right and bottom screen edges, so the
// desktop reads as one lit holo pane with the bar. Input passes through.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: glow

    property var modelData
    screen: modelData

    readonly property int reach: 28
    readonly property color edge: Qt.alpha(Theme.primary, 0.03)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    color: "transparent"
    WlrLayershell.namespace: "holo-glow"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: glow.reach
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: glow.edge }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: glow.reach
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: glow.edge }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: glow.reach
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: glow.edge }
        }
    }
}
