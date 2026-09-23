// Launcher state. Mod+d toggles it through `quickshell ipc call launcher toggle`.

pragma Singleton

import Quickshell
import Quickshell.I3
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    // The output that was focused when the launcher opened.
    property string screen
    // Executables on PATH, as wmenu-run offers them.
    property var commands: []
    // Commands run from the launcher, most recent first.
    property var recent: []

    // Recently run commands lead, the rest follow alphabetically.
    readonly property var ordered: {
        const known = new Set(commands);
        const front = recent.filter(c => known.has(c));
        const seen = new Set(front);
        return front.concat(commands.filter(c => !seen.has(c)));
    }

    function toggle() {
        if (!open) {
            screen = I3.focusedMonitor ? I3.focusedMonitor.name : Quickshell.screens[0].name;
            lister.running = true;
        }
        open = !open;
    }

    // Launch through Sway like its own exec bindings. A child of this service
    // would share its cgroup and die whenever the shell restarts.
    function run(command) {
        open = false;
        if (command.trim() === "") return;
        recent = [command].concat(recent.filter(c => c !== command)).slice(0, 200);
        history.setText(recent.join("\n") + "\n");
        I3.dispatch("exec \"" + command.replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"");
    }

    Process {
        id: lister
        command: [Paths.commands]
        stdout: StdioCollector {
            onStreamFinished: root.commands = text.split("\n").filter(c => c !== "")
        }
    }

    // Kept outside Quickshell's per-shell state, whose path changes with every rebuild.
    FileView {
        id: history
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
            + "/quickshell-launcher-history"
        printErrors: false
        onLoaded: root.recent = text().split("\n").filter(c => c !== "")
    }

    // Any other Sway binding, like Mod+arrows, closes the launcher. Mod+d's own
    // binding is left to the toggle it runs.
    I3IpcListener {
        subscriptions: ["binding"]
        onIpcEvent: event => {
            if (root.open && !JSON.parse(event.data).binding.command.includes("launcher toggle"))
                root.open = false;
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
    }
}
