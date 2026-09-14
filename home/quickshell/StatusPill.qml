// Status readout; a menu name enables hover and click interaction.

import QtQuick
import QtQuick.Layouts

Item {
    id: pill

    property string menu: ""
    readonly property bool opens: menu !== ""

    Layout.fillHeight: opens
    Layout.alignment: Qt.AlignVCenter

    property string glyph
    property string label
    property bool active: false
    property color tint: Theme.primary

    property bool alert: false

    signal hoverChanged(bool hovered)
    signal activated()

    // Expose the target size so the menu and pill can animate together.
    readonly property real targetWidth: row.implicitWidth + Tokens.padding.medium * 2

    implicitWidth: targetWidth
    implicitHeight: 22
    clip: true

    // Smooth changing readouts without pushing neighbouring pills abruptly.
    Behavior on implicitWidth { Anim { motion: Motion.spatial } }

    Rectangle {
        anchors.fill: parent

        radius: pill.opens ? 0 : Tokens.rounding.full
        topLeftRadius: pill.opens ? 2 : radius
        topRightRadius: pill.opens ? 2 : radius
        bottomLeftRadius: pill.opens ? 0 : radius
        bottomRightRadius: pill.opens ? 0 : radius

        color: pill.active
            ? Theme.primary
            : (hover.hovered && pill.opens ? Qt.alpha(Theme.primary, 0.10) : "transparent")

        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Text {
            text: pill.glyph
            visible: text !== ""
            color: pill.active ? Theme.background : (pill.alert ? pill.tint : Theme.hot)
            font.family: Theme.iconFont
            font.pixelSize: Tokens.fontSize.normal

            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }

        Text {
            text: pill.label
            visible: text !== ""
            color: pill.active ? Theme.background : Theme.hot
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small
            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }
    }

    HoverHandler {
        id: hover
        enabled: pill.opens
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: pill.hoverChanged(hovered)
    }

    TapHandler {
        enabled: pill.opens
        onTapped: pill.activated()
    }
}
