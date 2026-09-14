// Menu content hosted by Chrome, with independent page crossfades.

import QtQuick

Item {
    id: page

    required property var window
    required property string name

    property int contentWidth: 0
    property int contentHeight: 0
    property int maxContentHeight: contentHeight

    readonly property real pillAnchor: window.pillAnchor
    readonly property real pillRight: window.pillRight
    readonly property int pad: window.pad

    readonly property bool active: window.open && window.current === name

    anchors.fill: parent

    opacity: active ? 1 : 0
    visible: opacity > 0
    // Disable outgoing controls as soon as switching or closing begins.
    enabled: active
    Behavior on opacity {
        Anim { motion: page.active ? Motion.effect : Motion.fastEffect }
    }
}
