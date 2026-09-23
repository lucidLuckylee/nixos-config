// Status readout; a menu name or `clickable` enables hover and click interaction.

import QtQuick
import QtQuick.Layouts

Item {
    id: pill

    property string menu: ""
    readonly property bool opens: menu !== ""

    // A pill can act on its own without opening a menu.
    property bool clickable: false
    readonly property bool interactive: opens || clickable

    Layout.fillHeight: opens
    Layout.alignment: Qt.AlignVCenter

    property string glyph
    property string label
    // Own on-state for clickable pills; menu pills leave this false.
    property bool active: false
    property color tint: Theme.primary

    property bool alert: false

    // Every pill reports hover so the chrome's tab can mark it, menu or not.
    readonly property alias hovered: hover.hovered

    signal hoverChanged(bool hovered)
    signal activated()

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: 22
    clip: true

    // Smooth changing readouts without pushing neighbouring pills abruptly.
    Behavior on implicitWidth { Anim { motion: Motion.spatial } }

    Rectangle {
        anchors.fill: parent

        topLeftRadius: pill.opens ? 2 : 0
        topRightRadius: pill.opens ? 2 : 0

        // Menu pills are highlighted by the chrome's indicator instead.
        visible: pill.interactive
        color: pill.active
            ? Theme.primary
            : (hover.hovered ? Qt.alpha(Theme.primary, 0.10) : "transparent")

        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Text {
            text: pill.glyph
            visible: text !== ""
            color: pill.alert ? pill.tint : Theme.hot
            font.family: Theme.iconFont
            font.pixelSize: Tokens.fontSize.normal

            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }

        Text {
            text: pill.label
            visible: text !== ""
            color: Theme.hot
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small
        }
    }

    HoverHandler {
        id: hover
        cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: pill.hoverChanged(hovered)
    }

    TapHandler {
        enabled: pill.interactive
        onTapped: pill.activated()
    }
}
