// How things move.
//
// The curves and durations are Material 3 Expressive's motion tokens, the same
// set caelestia-dots/shell animates from. Using a published system rather than
// hand-picked numbers is the point: every transition in the shell is then one
// of a handful of named motions, and things that move for the same reason move
// the same way without anyone having to remember what they picked last time.
//
// ── Spatial vs effect ───────────────────────────────────────────────────
// The split matters more than the numbers. *Spatial* motions move something
// through space — a panel opening, a highlight sliding from one chip to the
// next — and their curves overshoot their target and settle back, which is
// what makes them read as objects with mass rather than as values being
// interpolated. *Effect* motions change something in place — a colour, an
// opacity — where an overshoot would just look like a flicker, so those curves
// approach their target and stop.
//
// The overshoot is why the y values below run past 1. A control point at
// y = 1.21 means the animation passes its destination and comes back; anything
// animating a size or position with one of these needs somewhere to overshoot
// into, or the compositor clips the part that goes past.
//
// Each token pairs a curve with the duration it was designed for, because
// using one without the other is how a spring ends up looking like a lurch.
// Read them as `Motion.spatial.curve` and `Motion.spatial.ms`, or hand the
// whole thing to Anim/CAnim, which is what those exist for.

pragma Singleton

import Quickshell

Singleton {
    // ── Spatial: things that move ───────────────────────────────────────
    readonly property var fastSpatial: ({
        curve: [0.42, 1.67, 0.21, 0.9, 1, 1],
        ms: 350
    })
    readonly property var spatial: ({
        curve: [0.38, 1.21, 0.22, 1, 1, 1],
        ms: 500
    })
    readonly property var slowSpatial: ({
        curve: [0.39, 1.29, 0.35, 0.98, 1, 1],
        ms: 650
    })

    // ── Effects: things that change in place ────────────────────────────
    readonly property var fastEffect: ({
        curve: [0.31, 0.94, 0.34, 1, 1, 1],
        ms: 150
    })
    readonly property var effect: ({
        curve: [0.34, 0.8, 0.34, 1, 1, 1],
        ms: 200
    })
    readonly property var slowEffect: ({
        curve: [0.34, 0.88, 0.34, 1, 1, 1],
        ms: 300
    })

    // ── Standard: no overshoot at all ───────────────────────────────────
    // For motion that has to look like it was told to stop rather than like
    // it chose to — closing, dismissing, anything reversing out of a state.
    readonly property var standard: ({
        curve: [0.2, 0, 0, 1, 1, 1],
        ms: 200
    })
}
