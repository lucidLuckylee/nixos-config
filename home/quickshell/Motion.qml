// Material 3 motion tokens. Spatial curves overshoot; effect curves do not.

pragma Singleton

import Quickshell

Singleton {
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

    readonly property var standard: ({
        curve: [0.2, 0, 0, 1, 1, 1],
        ms: 200
    })
}
