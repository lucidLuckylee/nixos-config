// A black box with a glowing turquoise inner line, like Sway's focused border.

import QtQuick

Rectangle {
    id: frame

    property bool shown: true

    color: Theme.background
    opacity: shown ? 1 : 0
    Behavior on opacity { Anim { motion: Motion.fastEffect } }

    // A bright core line with fading rings on either side reads as a glow.
    Repeater {
        model: [{ inset: 1, alpha: 0.3 }, { inset: 2, alpha: 1 },
                { inset: 3, alpha: 0.3 }, { inset: 4, alpha: 0.1 }]

        Rectangle {
            required property var modelData
            anchors.fill: parent
            anchors.margins: modelData.inset
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Qt.lighter(Theme.primary, 1.35), modelData.alpha)
        }
    }
}
