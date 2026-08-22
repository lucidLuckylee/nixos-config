// A glyph in a hairline box, lit when the thing it names is on.
//
// The shell's own control: a 1px border, a 4px radius, and a single Nerd Font
// glyph. The bar's readouts are already built this way, so a chip on the
// Bluetooth menu is recognisably the same desktop rather than a Material switch
// that wandered in from another one.
//
// Drawn inverted, because it sits on the menu's accent-coloured host rather than
// on the dark panel: dark ink on a bright ground, and "lit" means filled with the
// dark colour rather than with the accent, since the accent is already the ground
// it is standing on.
//
// It replaces first a pair of sliding switches and then a pair of capitalised
// words. The switch spent most of its area on chrome — track, knob, shadow — to
// say one bit, and needed a written label beside it because a bare track says
// nothing about what it controls. A glyph is that label, so the whole control is
// the size of the thing it was previously only decorating.

import QtQuick

Item {
    id: chip

    property string glyph
    property bool active: false
    property bool available: true
    // Breathes while the thing it names is working rather than merely on.
    property bool working: false

    signal toggled()

    implicitWidth: 26
    implicitHeight: 22

    opacity: available ? 1 : 0.35
    Behavior on opacity { Anim { motion: Motion.fastEffect } }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.extraSmall

        color: chip.active
            ? Theme.background
            : (hover.hovered && chip.available ? Qt.alpha(Theme.background, 0.14) : "transparent")
        border.width: 1
        border.color: Qt.alpha(Theme.background, chip.active ? 1 : 0.45)

        Behavior on color { CAnim { motion: Motion.fastEffect } }
        Behavior on border.color { CAnim { motion: Motion.fastEffect } }
    }

    Text {
        id: text
        anchors.centerIn: parent
        text: chip.glyph
        color: chip.active ? Theme.primary : Qt.alpha(Theme.background, 0.8)
        font.family: Theme.iconFont
        font.pixelSize: Tokens.fontSize.normal

        Behavior on color { CAnim { motion: Motion.fastEffect } }

        // The one moving thing on the menu, and only while there is background
        // work to report. On the glyph rather than on the chip, because the
        // chip's own opacity is already saying whether it can be used.
        SequentialAnimation on opacity {
            running: chip.working
            loops: Animation.Infinite
            onStopped: text.opacity = 1
            NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        enabled: chip.available
        onTapped: chip.toggled()
    }
}
