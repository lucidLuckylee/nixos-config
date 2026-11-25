// A list row in a menu: a hover wash, the glowing frame while `current`, and a
// staggered pop-in each time the menu opens. Rows recreated by a model update
// while the menu is already open appear in place instead of popping in again.

import QtQuick
import QtQuick.Layouts

Item {
    id: row

    // The MenuPage this row lives in; its `entering` window drives the pop-in.
    required property var page
    property int entryIndex: 0

    property bool current: false
    property bool hoverable: true
    // A clickable row reports clicks anywhere on it.
    property bool clickable: false
    readonly property alias hovered: hover.hovered

    signal clicked()

    default property alias content: layout.data

    Layout.fillWidth: true
    Layout.preferredHeight: Tokens.size.row

    function popIn() {
        entry.stop();
        opacity = 0;
        scale = 0.7;
        entry.start();
    }
    Component.onCompleted: if (page.entering) popIn()
    Connections {
        target: row.page
        function onEnteringChanged() { if (row.page.entering) row.popIn(); }
    }

    SequentialAnimation {
        id: entry
        PauseAnimation { duration: row.entryIndex * 40 }
        ParallelAnimation {
            Anim { target: row; property: "opacity"; to: 1; motion: Motion.effect }
            Anim { target: row; property: "scale"; to: 1; motion: Motion.spatial }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: !row.current && row.hoverable && hover.hovered
            ? Qt.alpha(Theme.background, 0.10) : "transparent"

        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    Frame {
        anchors.fill: parent
        shown: row.current
    }

    HoverHandler {
        id: hover
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        enabled: row.clickable
        onTapped: row.clicked()
    }

    // Clear the frame's four-pixel glow on both sides.
    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small
    }
}
