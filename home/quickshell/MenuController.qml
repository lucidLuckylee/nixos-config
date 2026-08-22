// Which bar menu is open, and the hover rules that decide it.
//
// One of these per screen (see shell.qml), holding a *name* rather than one
// controller object per pill. Only one menu is ever open — two would overlap,
// both hanging off pills the pointer had left — so the whole state is a single
// string, and "close whichever was open before" costs nothing: it is the same
// assignment that opens the new one. The per-pill version of this file needed
// an `opening` signal and a `dismiss()` on every other controller to get there.
//
// Hover rather than click is not a preference. A layer shell is told nothing
// about clicks that land elsewhere on screen, so "click outside to dismiss"
// needs a fullscreen transparent catcher, and that swallows the first click of
// whatever you were actually reaching for. Hover has no such problem: leaving
// is an event the surface does get told about.

import QtQuick

QtObject {
    id: controller

    // The pill the pointer is resting on, "" for none. Written through
    // `hover()` rather than assigned: crossing from one pill straight to the
    // next produces an enter and a leave in no guaranteed order, and a leave
    // applied after the enter it was overtaken by would blank the wrong name.
    property string hoveredPill: ""
    function hover(name, hovered) {
        if (hovered) hoveredPill = name;
        else if (hoveredPill === name) hoveredPill = "";
    }

    // Whether the pointer is anywhere on the shell's shape — the bar's strip or
    // the box hanging off it (see Bar.qml). One flag, not one per menu, and not
    // one for the box and another for the pills: the bar and an open menu are
    // one object, so being on any of it is being on it.
    property bool shapeHovered: false

    // The menu that is open, "" when none is.
    property string openMenu: ""

    // The menu the box is *showing*. The same name, except that it outlives the
    // close — `openMenu` empties the moment a close begins, and the fading box
    // still has to know what it is fading out of.
    property string shown: ""

    onOpenMenuChanged: {
        if (openMenu !== "") shown = openMenu;
        reconsider();
    }
    onHoveredPillChanged: {
        if (hoveredPill !== "") opener.restart();
        else opener.stop();
        reconsider();
    }
    onShapeHoveredChanged: reconsider()

    // A menu closes when the pointer leaves the shape, and only then. There is
    // no separate test for "on its own pill" — a pill is on the strip, and the
    // strip is the shape.
    function reconsider() {
        if (openMenu === "" || shapeHovered) closer.stop();
        else closer.restart();
    }

    // Hover intent. The pills sit in a row, so the pointer crosses several of
    // them on the way to any one; without a beat first, three menus would flash
    // open on the way to the fourth. With a box already out that beat collapses
    // to nearly nothing — resting on a second pill should morph the open box
    // over to it rather than close-wait-reopen, which is the popout behaviour of
    // caelestia-dots/shell.
    readonly property Timer opener: Timer {
        interval: controller.openMenu !== "" ? 30 : 160
        onTriggered: controller.openMenu = controller.hoveredPill
    }

    // The pointer is off the shell entirely by the time this is running, so it
    // is only long enough to forgive a pointer that clipped the outside of a
    // corner on its way across.
    readonly property Timer closer: Timer {
        interval: 200
        onTriggered: controller.openMenu = ""
    }
}
