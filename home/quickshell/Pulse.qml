// Fade in and out while running. Stopping finishes the cycle, so the target
// always comes to rest fully opaque. Use as `Pulse on opacity { running: … }`.

import QtQuick

SequentialAnimation {
    id: pulse

    property int period: 1400
    property real low: 0.3

    loops: Animation.Infinite
    alwaysRunToEnd: true

    NumberAnimation { from: 1; to: pulse.low; duration: pulse.period / 2; easing.type: Easing.InOutSine }
    NumberAnimation { from: pulse.low; to: 1; duration: pulse.period / 2; easing.type: Easing.InOutSine }
}
