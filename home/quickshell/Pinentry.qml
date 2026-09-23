// Passphrase requests from the pinentry-quickshell helper (see pinentry.py).
// Each request and reply is one JSON line; a reply carries `pin` or `cancel`.

pragma Singleton

import Quickshell
import Quickshell.I3
import Quickshell.Io

Singleton {
    id: root

    // The open request's connection; null while nothing is asked.
    property var socket: null
    readonly property bool pending: socket !== null

    property string title
    property string description
    property string error
    // The output that was focused when the request arrived.
    property string screen

    function answer(pin) { reply({ pin: pin }); }
    function cancel() { reply({ cancel: true }); }

    function reply(message) {
        if (!socket) return;
        socket.write(JSON.stringify(message) + "\n");
        socket.flush();
        socket = null;
    }

    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-pinentry.sock"

        handler: Socket {
            id: connection

            parser: SplitParser {
                onRead: line => {
                    const request = JSON.parse(line);
                    root.title = request.title ?? "";
                    root.description = request.desc ?? "";
                    root.error = request.error ?? "";
                    root.screen = I3.focusedMonitor
                        ? I3.focusedMonitor.name : Quickshell.screens[0].name;
                    root.socket = connection;
                }
            }

            // gpg-agent gave up on this pinentry, e.g. after its timeout.
            onConnectedChanged: {
                if (!connected && root.socket === connection) root.socket = null;
            }
        }
    }
}
