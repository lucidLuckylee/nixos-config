// Menu header for a radio: the power chip under the pill and a scan chip to
// its left that only shows while the radio is on.

import QtQuick
import QtQuick.Layouts

Item {
    id: header

    required property var page
    property string onGlyph
    property string offGlyph
    property bool live: false
    property bool available: true
    property bool scanning: false

    signal powerToggled()
    signal scanToggled()

    Layout.fillWidth: true
    Layout.preferredHeight: Tokens.size.control

    Chip {
        id: power
        x: Math.max(0, Math.min(parent.width - width, header.page.pillAnchor))
        anchors.verticalCenter: parent.verticalCenter

        glyph: header.live ? header.onGlyph : header.offGlyph
        active: header.live
        available: header.available
        onToggled: header.powerToggled()
    }

    Chip {
        x: power.x - width - Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter

        // Chip animates its own opacity.
        opacity: header.live ? 1 : 0
        visible: opacity > 0

        glyph: String.fromCodePoint(0xf0349)  // md-magnify
        active: header.scanning
        available: header.live
        working: header.scanning
        onToggled: header.scanToggled()
    }
}
