// Colour animation using a non-overshooting effect curve.

import QtQuick

ColorAnimation {
    property var motion: Motion.effect

    duration: motion.ms
    easing.type: Easing.Bezier
    easing.bezierCurve: motion.curve
}
