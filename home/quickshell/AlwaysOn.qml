// Always-on state, read from the runtime file the helper script maintains.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    function toggle() {
        toggler.running = true;
    }

    // Write the file before watching it so a fresh session starts in sync.
    Process {
        command: [Paths.alwaysOn]
        running: true
        onExited: state.path = Quickshell.env("XDG_RUNTIME_DIR") + "/sway-always-on"
    }

    Process {
        id: toggler
        command: [Paths.alwaysOn, "toggle"]
    }

    FileView {
        id: state
        watchChanges: true
        onLoaded: root.active = text().trim() === "on"
        onFileChanged: reload()
    }
}
