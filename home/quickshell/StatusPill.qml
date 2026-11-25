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

    // Standalone buttons use the same full-height background as the hover tab.
    Layout.fillHeight: interactive
    Layout.alignment: Qt.AlignVCenter

    property string glyph
    property string label
    // Own on-state for clickable pills; menu pills leave this false.
    property bool active: false
    property bool highlighted: false
    property color tint: Theme.primary

    property bool alert: false

    // Every pill reports hover so the chrome's tab can mark it, menu or not.
    readonly property alias hovered: hover.hovered

    signal hoverChanged(bool hovered)
    signal activated()

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Tokens.size.control
    clip: true

    // Smooth changing readouts without pushing neighbouring pills abruptly. No
    // overshoot: dipping below the new width would clip the label's ends, and
    // every pill to the left would bounce.
    Behavior on implicitWidth { Anim { motion: Motion.standard } }

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

        Icon {
            text: pill.glyph
            visible: text !== ""
            color: pill.active || pill.highlighted ? Theme.hot
                : (pill.alert ? pill.tint : Theme.warm)

            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }

        Label {
            text: pill.label
            visible: text !== ""
            color: pill.active || pill.highlighted ? Theme.hot : Theme.warm

            Behavior on color { CAnim { motion: Motion.fastEffect } }
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
