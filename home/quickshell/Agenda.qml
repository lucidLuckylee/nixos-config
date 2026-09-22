// CalDAV events from the agenda cache, refreshed by the helper script.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string cache:
        (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
        + "/quickshell/agenda.json"

    // Rows carry `start` and `end` as Date; all-day ends are exclusive.
    property var events: []
    property date synced: new Date(0)
    readonly property bool syncing: sync.running
    property bool failed: false

    readonly property int refreshMinutes: 10

    function refresh() {
        if (!sync.running) sync.running = true;
    }

    function refreshIfStale() {
        if (Date.now() - synced.getTime() > refreshMinutes * 60000) refresh();
    }

    // All-day rows arrive as plain dates; keep them on local midnight.
    function toDate(value, allDay) {
        if (!allDay) return new Date(value);
        const [year, month, day] = value.split("-").map(Number);
        return new Date(year, month - 1, day);
    }

    function eventsOn(day) {
        const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
        return events.filter(e => e.start < dayEnd && e.end > dayStart);
    }

    function open(url) {
        if (url) Quickshell.execDetached(["xdg-open", url]);
    }

    function load() {
        const raw = file.text().trim();
        if (raw === "") return;
        const data = JSON.parse(raw);
        events = data.events.map(e => Object.assign({}, e, {
            start: toDate(e.start, e.allDay),
            end: toDate(e.end, e.allDay)
        }));
        synced = new Date(data.synced);
    }

    Process {
        id: sync
        command: [Paths.agenda, root.cache]
        running: true
        onExited: exitCode => root.failed = exitCode !== 0
    }

    Timer {
        interval: root.refreshMinutes * 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    FileView {
        id: file
        path: root.cache
        watchChanges: true
        printErrors: false
        onLoaded: root.load()
        onFileChanged: reload()
    }
}
