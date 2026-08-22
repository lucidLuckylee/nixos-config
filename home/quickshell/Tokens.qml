// How big things are.
//
// Material 3's shape and spacing scales, the same values caelestia-dots/shell
// builds from. Sizes come from a scale for the same reason motion comes from
// one (see Motion.qml): a radius or a gap picked by eye is a radius nobody can
// match later, and a shell whose corners are 2px here and 9px there reads as
// unfinished no matter how carefully each one was chosen.
//
// The scale is deliberately coarse. Two adjacent steps are visibly different,
// so there is never a reason to reach for a number in between — if something
// looks wrong at `medium` it wants `large`, not 14.
//
// `full` means "as round as this can get": handed to a radius it produces a
// stadium, whatever the height.

pragma Singleton

import Quickshell
// QtObject is a QtQml type, not a QML language primitive: without this import
// every group below fails with "QtObject is not a type".
import QtQml

Singleton {
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property int full: 9999
    }

    readonly property QtObject spacing: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
    }

    readonly property QtObject padding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
    }

    // The type scale. Larger than what the shell used to run at — a bar set in
    // 9px was legible but read as a status line rather than as part of the
    // desktop's furniture, which is most of what made it feel thin next to the
    // shells this borrows from.
    readonly property QtObject fontSize: QtObject {
        readonly property int small: 11
        readonly property int smaller: 12
        readonly property int normal: 13
        readonly property int larger: 15
        readonly property int large: 18
        readonly property int extraLarge: 28
    }
}
