// A NumberAnimation that takes one of Motion's tokens.
//
//     Behavior on x { Anim { motion: Motion.fastSpatial } }
//
// Exists so a curve and the duration it was tuned for cannot be separated:
// hand-writing `easing.bezierCurve` at each call site is how half the shell
// ends up on a 500ms curve run over 150ms, which reads as the animation being
// cut off rather than as a faster version of the same motion.

import QtQuick

NumberAnimation {
    property var motion: Motion.spatial

    duration: motion.ms
    easing.type: Easing.Bezier
    easing.bezierCurve: motion.curve
}
