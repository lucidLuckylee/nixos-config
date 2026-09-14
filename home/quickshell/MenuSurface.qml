// Put the bar and its menu inside this item. Hover handlers on an overlapping
// sibling do not reliably receive the controls' hover events; a common parent
// keeps observing while the pointer crosses pills, buttons and MouseAreas.

import QtQuick

Item {
    id: surface

    // Hover can lag behind an exclusive MouseArea grab. Track the position
    // during the gesture too, so releasing outside starts the close timer.
    property point pointerPosition: Qt.point(-1, -1)
    readonly property bool hovered: hover.hovered && contains(pointerPosition)
    readonly property alias pressed: press.active

    HoverHandler {
        id: hover
        blocking: false
        onPointChanged: if (hovered) surface.pointerPosition = point.position
    }

    // A passive grab observes the full gesture, including a slider dragged
    // outside the menu, while the control still receives its press and release.
    Item {
        anchors.fill: parent
        z: 1
        PointHandler {
            id: press
            acceptedButtons: Qt.LeftButton
            target: null
            onPointChanged: if (active) surface.pointerPosition = point.position
        }
    }
}
