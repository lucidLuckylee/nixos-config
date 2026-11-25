// Compact icon button for menu actions and toggles.

import QtQuick

Item {
    id: chip

    property string glyph
    property bool active: false
    property bool available: true
    property bool working: false

    signal toggled()

    implicitWidth: Tokens.size.chip
    implicitHeight: Tokens.size.control

    opacity: available ? 1 : 0.35
    Behavior on opacity { Anim { motion: Motion.fastEffect } }

    Rectangle {
        anchors.fill: parent

        color: chip.active
            ? "transparent"
            : tap.pressed ? Qt.alpha(Theme.background, 0.24)
            : (hover.hovered && chip.available ? Qt.alpha(Theme.background, 0.14) : "transparent")
        border.width: 1
        border.color: Qt.alpha(Theme.background, chip.active ? 1 : 0.45)

        Behavior on color { CAnim { motion: Motion.fastEffect } }
        Behavior on border.color { CAnim { motion: Motion.fastEffect } }
    }

    Frame {
        anchors.fill: parent
        shown: chip.active
    }

    Icon {
        anchors.centerIn: parent
        text: chip.glyph
        color: chip.active ? Theme.primary : Qt.alpha(Theme.background, 0.8)

        Behavior on color { CAnim { motion: Motion.fastEffect } }
        Pulse on opacity {
            running: chip.working
            period: 1800
            low: 0.35
        }
    }

    HoverHandler {
        id: hover
        enabled: chip.enabled && chip.available
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        enabled: chip.available
        onTapped: chip.toggled()
    }
}
