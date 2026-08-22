// A ColorAnimation that takes one of Motion's tokens. See Anim.qml.
//
// Defaults to `effect` rather than `spatial`: a colour has no position to
// overshoot past, and a curve that ran past its target would just show a
// wrong colour for a frame or two on the way.

import QtQuick

ColorAnimation {
    property var motion: Motion.effect

    duration: motion.ms
    easing.type: Easing.Bezier
    easing.bezierCurve: motion.curve
}
