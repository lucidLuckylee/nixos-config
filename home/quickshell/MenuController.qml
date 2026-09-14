// One menu per screen. Hover opens after a short dwell; leaving the whole
// surface closes after a grace period. Clicks act immediately, and a held
// pointer keeps the menu in place until its control has finished the gesture.

import QtQuick

QtObject {
    id: controller

    property string hoveredPill: ""
    property bool shapeHovered: false
    property bool pointerPressed: false

    property string openMenu: ""
    // Keep the outgoing page's geometry until the closing animation finishes.
    property string shown: ""
    // A click can dismiss a hovered pill without hover immediately reopening it.
    property string dismissedPill: ""

    readonly property int openDelay: 160
    readonly property int switchDelay: 110
    readonly property int closeDelay: 350
    readonly property bool keepOpen:
        shapeHovered || hoveredPill !== "" || pointerPressed

    function hover(name, hovered) {
        if (hovered) {
            if (hoveredPill !== name) dismissedPill = "";
            hoveredPill = name;
        } else if (hoveredPill === name) {
            // An old pill's leave may arrive after the next pill's enter.
            hoveredPill = "";
            dismissedPill = "";
        }
    }

    function toggle(name) {
        if (name === "") return;
        opener.stop();
        dismissedPill = openMenu === name ? name : "";
        openMenu = openMenu === name ? "" : name;
    }

    onOpenMenuChanged: {
        if (openMenu !== "") shown = openMenu;
        reconsider();
    }
    onHoveredPillChanged: scheduleOpen()
    onPointerPressedChanged: scheduleOpen()
    onKeepOpenChanged: reconsider()

    function scheduleOpen() {
        opener.stop();
        if (!pointerPressed && hoveredPill !== ""
                && hoveredPill !== openMenu && hoveredPill !== dismissedPill)
            opener.start();
    }

    function reconsider() {
        if (openMenu === "" || keepOpen) closer.stop();
        // Start once per departure. Other state changes must not push the
        // deadline back indefinitely while the pointer is already outside.
        else if (!closer.running) closer.start();
    }

    readonly property Timer opener: Timer {
        interval: controller.openMenu !== ""
            ? controller.switchDelay : controller.openDelay
        onTriggered: {
            if (!controller.pointerPressed && controller.hoveredPill !== ""
                    && controller.hoveredPill !== controller.dismissedPill)
                controller.openMenu = controller.hoveredPill;
        }
    }

    readonly property Timer closer: Timer {
        interval: controller.closeDelay
        onTriggered: {
            if (!controller.keepOpen) controller.openMenu = "";
        }
    }
}
