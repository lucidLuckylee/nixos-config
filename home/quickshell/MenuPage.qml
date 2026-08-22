// One menu's contents, as a page inside the single menu window.
//
// There is one Chrome per screen and it serves every pill; each menu
// file (BluetoothFlyout.qml, WifiMenu.qml, ...) is one of these, declaring the
// three things the window needs — how big its contents are, how big they can
// get, and what they are — plus the `name` the window switches on.
//
// Moving the pointer from one pill to another does not close one menu and open
// another: the window slides and resizes under the new pill while the outgoing
// page fades out and the incoming one fades in, which is the whole reason the
// pages share a window. The pattern is caelestia-dots/shell's popout Content —
// one morphing container, per-popout crossfade — with the fade timings theirs
// too: out fast, in slower, so mid-switch the box is briefly mostly empty
// rather than briefly double-exposed.
//
// The page fills the window's live content area rather than holding its own
// declared size, and that is load-bearing: controls pinned to `pillAnchor`
// clamp themselves against `parent.width`, which has to be the *animating*
// width for the clamp to be where the box actually is mid-resize.

import QtQuick

Item {
    id: page

    // The Chrome this page lives in. Set by Bar.qml, which declares them.
    required property var window
    // Which pill this page answers for — matched against `window.current`.
    required property string name

    property int contentWidth: 0
    property int contentHeight: 0
    property int maxContentHeight: contentHeight

    // The anchors contents pin themselves to, passed through so a page's
    // internals can keep saying `menu.pillAnchor` — see Chrome.qml for what
    // each one is and why.
    readonly property real pillAnchor: window.pillAnchor
    readonly property real pillRight: window.pillRight
    readonly property int pad: window.pad

    readonly property bool active: window.current === name

    anchors.fill: parent

    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        Anim { motion: page.active ? Motion.effect : Motion.fastEffect }
    }
}
