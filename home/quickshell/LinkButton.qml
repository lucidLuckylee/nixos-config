// Connect or disconnect icon at the end of a list row; pulses while busy.

import QtQuick

Icon {
    id: link

    property bool connected: false
    property bool busy: false

    signal clicked()

    text: String.fromCodePoint(connected ? 0xf0338    // md-link-off
                                         : 0xf0337)   // md-link
    color: busy ? Theme.warm
         : connected ? Theme.primary
         : (hover.hovered ? Theme.background : Qt.alpha(Theme.background, 0.6))
    leftPadding: Tokens.spacing.extraSmall
    rightPadding: Tokens.spacing.extraSmall

    Behavior on color { CAnim { motion: Motion.fastEffect } }
    Pulse on opacity { running: link.busy }

    HoverHandler {
        id: hover
        cursorShape: link.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
    }
    TapHandler {
        enabled: !link.busy
        onTapped: link.clicked()
    }
}
