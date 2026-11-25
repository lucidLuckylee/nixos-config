// Menu content hosted by Chrome, with independent page crossfades.

import QtQuick

Item {
    id: page

    required property var window
    required property string name

    property int contentWidth: 0
    property int contentHeight: 0
    property int maxContentHeight: contentHeight
    // Set while the page takes typed input: the bar then holds the keyboard and keeps the menu open.
    property bool typing: false

    readonly property real pillAnchor: window.pillAnchor
    readonly property real pillRight: window.pillRight
    readonly property int pad: window.pad

    readonly property bool active: window.open && window.current === name

    // Briefly true after the page opens, so its list rows pop in once per opening.
    readonly property bool entering: settle.running
    Timer {
        id: settle
        interval: 400
    }

    anchors.fill: parent

    opacity: 0
    visible: opacity > 0
    // Disable outgoing controls as soon as switching or closing begins.
    enabled: active

    // On a switch the incoming page waits for the outgoing one to fade, so
    // the two never overlap; a fresh open fades in at once.
    Connections {
        target: page
        function onActiveChanged() {
            if (page.active) settle.restart();
            fade.stop();
            fade.delay = page.active && page.window.reveal > 0.5 ? Motion.fastEffect.ms : 0;
            fade.motion = page.active ? Motion.effect : Motion.fastEffect;
            fade.to = page.active ? 1 : 0;
            fade.start();
        }
    }

    SequentialAnimation {
        id: fade

        property int delay: 0
        property var motion: Motion.effect
        property real to: 0

        PauseAnimation { duration: fade.delay }
        Anim { target: page; property: "opacity"; to: fade.to; motion: fade.motion }
    }
}
