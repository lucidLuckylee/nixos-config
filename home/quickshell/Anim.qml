// Number animation using a paired duration and curve from Motion.

import QtQuick

NumberAnimation {
    property var motion: Motion.spatial

    duration: motion.ms
    easing.type: Easing.Bezier
    easing.bezierCurve: motion.curve
}
