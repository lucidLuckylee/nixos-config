// The bar: one strip across the top of every monitor.
//
// This replaces swaybar and i3status rather than sitting next to them (see
// ../linux.nix, where sway's own `bars` list is now empty). It carries the same
// four readouts i3status did — wifi, volume, free disk, the clock — plus a
// battery and the Bluetooth pill. Four of them open a menu, which they say by
// naming it; the rest are readouts.
//
// Everything here is read from a service rather than shelled out to a command:
// Quickshell speaks sway's IPC, NetworkManager's D-Bus, PipeWire and BlueZ
// directly, so there is no polling loop and no status line being re-parsed
// once a second. Free disk space is the one exception — nothing exposes that
// over a bus — and it is a `df` on a slow timer.
//
// ── One surface, bar and menus together ────────────────────────────────
// This window is taller than the bar: it covers the strip *and* the space any
// open menu hangs in, and reserves only the strip. The two used to be separate
// layer surfaces, and everything awkward about the old arrangement came from
// that — a menu could not draw on the bar's own bottom edge, so interrupting
// that edge meant painting a rectangle of the bar's colour over it and keeping
// the two surfaces' idea of the box in agreement across the gap.
//
// In one surface there is nothing to keep in agreement. Chrome.qml draws the
// strip, its edge, the box and the indicator as two paths of a single Shape,
// and the menus are declared here, inside it, because they are part of the bar
// rather than something hung off it.
//
// The consequence to know: `exclusiveZone` is now set explicitly to
// `barHeight`, not left on Auto. Auto follows `implicitHeight`, which here is
// the whole strip *plus* the menu space, and would reserve a band of empty
// screen under the bar.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    // ── The menus ───────────────────────────────────────────────────────
    // Which pill is lit, by name, and which page the box is showing. Both are
    // decided by MenuController (see shell.qml) rather than here: the bar
    // reports where the pointer is and draws what it is told.
    //
    // `shown` outlives `openMenu` by the length of the close — the box on its
    // way back into the bar still has to know what it is closing on.
    property string openMenu: ""
    property string shown: ""
    signal pillHover(string name, bool hovered)

    // Whether the pointer is anywhere on the shape — the strip, or the box
    // hanging off it. One handler covering the whole window says exactly that
    // and nothing more, because the mask below is the shape: outside it the
    // compositor does not deliver the surface a pointer at all, so there is no
    // region left to test against by hand.
    //
    // The bar and an open menu are one object, so this is what a menu stays
    // open for. Sliding off a pill onto the empty strip beside it, or up out of
    // the box and across the bar, does not leave the object and does not close
    // it; only leaving the shape does.
    readonly property alias shapeHovered: shapeHover.hovered

    // How tall the strip is, and so how much of this window is bar. It is as
    // tall as its contents need and no taller — at this type scale, enough for
    // a stadium pill with real padding around its text.
    readonly property int barHeight: 28

    // Where a menu's pill is, measured from the right edge of the screen, and
    // how wide it is. A menu needs both to run its indicator up into the bar
    // underneath that exact pill — see the tongue in Chrome.qml.
    //
    // Found by walking the cluster for the pill that claims the name, rather
    // than by a property per pill: a new pill that opens something is then a
    // `menu` on it and nothing else anywhere.
    //
    // Measured from `targetWidth`, never from the live width. The pills animate
    // their widths when a label changes, so a live measurement is a number in
    // motion, and the menu chasing it is the stutter Chrome describes; these
    // step once and the menu animates the step. `x` is not used at all for the
    // same reason — it is the layout's answer to the live widths — so the gap
    // is summed from the pills to the right of this one instead.
    function menuGap(name) {
        const pills = cluster.children;
        let gap = cluster.anchors.rightMargin;
        let past = false;
        for (let i = 0; i < pills.length; i++) {
            const pill = pills[i];
            if (!pill.visible) continue;
            if (past) gap += pill.targetWidth + cluster.spacing;
            if (pill.menu === name) past = true;
        }
        return past ? gap : 0;
    }

    function menuWidth(name) {
        const pills = cluster.children;
        for (let i = 0; i < pills.length; i++)
            if (pills[i].menu === name) return pills[i].targetWidth;
        return 0;
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // The strip plus room for the largest menu under whichever pill it hangs
    // from. Fixed, so the surface is never resized — a layer surface cannot be
    // resized smoothly, and a full-width one never needs to be.
    implicitHeight: barHeight + chrome.maxBoxHeight

    // Only the strip is reserved; the menu space overlaps whatever is below.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight

    // Nothing is painted outside the shape, and `mask` keeps the surface from
    // taking input outside it either: the strip always, and the box while it is
    // out. Regions compose, so this is one freeform region rather than the
    // bounding rectangle of the two — a closed menu leaves the desktop under
    // the bar completely untouched, and an open one only claims its own box.
    mask: Region {
        x: 0
        y: 0
        width: bar.width
        height: bar.barHeight

        // Combined with the strip, not intersected — the two do not overlap, so
        // an intersection would be empty and the surface would take no input at
        // all. Combine is the default; it is named here because the failure is
        // silent and total.
        Region {
            intersection: Intersection.Combine

            x: chrome.boxX
            y: bar.barHeight
            width: chrome.boxWidth
            height: chrome.boxHeight

            // The same corners the box is drawn with. A square region would
            // take the pointer in two 12px corners that are visibly desktop,
            // and — now that hovering the shape is what holds a menu open —
            // hold it open from outside its own outline.
            bottomLeftRadius: chrome.boxRadius
            bottomRightRadius: chrome.boxRadius
        }
    }

    color: "transparent"
    WlrLayershell.namespace: "holo-bar"

    // Covers the window, and so covers the shape: see `shapeHovered` above.
    // A HoverHandler does not consume, so the pills still see their own.
    Item {
        anchors.fill: parent
        HoverHandler { id: shapeHover }
    }

    // No text is typed into these menus, and taking the keyboard would steal it
    // from the window being worked in every time one is opened.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── Sources ─────────────────────────────────────────────────────────

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // PipeWire only populates a node's `audio` once something is tracking it;
    // an untracked node has the volume of a stub. The tracker is what makes
    // the readout follow the volume keys.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        return devices.find(d => d.type === DeviceType.Wifi) ?? null;
    }
    readonly property var wifiNetwork:
        wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    // NetworkManager reports signal strength as a percentage and other
    // backends report a fraction; both arrive here as a double, so anything
    // above 1 is read as the percentage it already is.
    readonly property real wifiStrength: {
        if (!wifiNetwork) return 0;
        const raw = wifiNetwork.signalStrength;
        return raw > 1 ? raw / 100 : raw;
    }

    // The link rate the old status line also showed is deliberately not here:
    // NetworkManager knows it but does not put it on the bus, so it would cost
    // an nmcli subprocess on a timer for a number nobody acts on.

    readonly property var connectedBtDevice: {
        if (!Bluetooth.defaultAdapter) return null;
        return Bluetooth.defaultAdapter.devices.values.find(d => d.connected) ?? null;
    }

    // `df` is cheap but it is still a process; once a minute is far more often
    // than a disk fills up. `-P` pins the output to one line per filesystem,
    // which is the difference between parsing a column and parsing a wrap.
    property string diskFree: "--"

    Process {
        id: df
        command: [Paths.diskFree]
        running: true
        stdout: SplitParser {
            onRead: line => bar.diskFree = line.trim()
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: df.running = true
    }

    // ── The strip ───────────────────────────────────────────────────────

    // Everything the shell draws — the bar's flat field, the line along its
    // underside, the box and the indicator column — in one Shape. The menus
    // stand inside it. See Chrome.qml.
    //
    // A flat field rather than a translucent one: translucent, the bar would
    // show the wallpaper through itself while the windows below show their own
    // content — the same fill over two different grounds, which reads as two
    // different colours.
    Chrome {
        id: chrome
        anchors.fill: parent

        barHeight: bar.barHeight
        open: bar.openMenu !== ""
        current: bar.shown

        // Where the shown pill is and how wide it is, so the indicator comes
        // down under that exact pill.
        pillGap: bar.menuGap(bar.shown)
        pillWidth: bar.menuWidth(bar.shown)

        WifiMenu { window: chrome }
        VolumeMenu { window: chrome }
        BluetoothFlyout { window: chrome }
        CalendarMenu { window: chrome }
    }

    // The controls, on the strip and over the drawing.
    Item {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: bar.barHeight

        // Flush with the screen edge, both ends. The chips and pills carry
        // their own padding, so the text still has room; what goes away is the
        // strip of empty bar before the first one and after the last.
        //
        // Full height rather than centred: the focused chip is meant to run
        // all the way to the bottom edge, so that it reads as the tab the
        // window below it is hanging from.
        Workspaces {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            monitor: bar.modelData ? bar.modelData.name : ""
        }

        RowLayout {
            id: cluster
            anchors.right: parent.right
            // The same inset as a menu's frame, and that is not a coincidence.
            // A menu hangs its box under its pill with `frame` of panel to the
            // right of the indicator; if the last pill sat closer to the screen
            // edge than that, the box would clamp against the edge and the
            // column would come down a few pixels to the left of the pill it
            // belongs to. Invisible while the bar's hairline ran through it,
            // and a visible step now that the line is cut — see the notch
            // above. At exactly `frame` the last pill's menu lands square.
            anchors.rightMargin: Tokens.spacing.medium
            // Top to bottom rather than centred, so the Bluetooth pill can run
            // the full height of the bar as a tab. The readouts stay centred
            // within it individually.
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Tokens.spacing.extraSmall

            // ── Wifi ────────────────────────────────────────────────────
            StatusPill {
                menu: "wifi"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)

                glyph: {
                    if (!bar.wifiDevice || !Networking.wifiEnabled)
                        return String.fromCodePoint(0xf05aa);  // md-wifi-off
                    if (!bar.wifiNetwork)
                        return String.fromCodePoint(0xf092b);  // md-wifi-strength-alert-outline

                    if (bar.wifiStrength > 0.75) return String.fromCodePoint(0xf0928);
                    if (bar.wifiStrength > 0.5)  return String.fromCodePoint(0xf0925);
                    if (bar.wifiStrength > 0.25) return String.fromCodePoint(0xf0922);
                    return String.fromCodePoint(0xf091f);      // md-wifi-strength-1..4
                }

                // SSID and signal quality, as the status line had it.
                label: bar.wifiNetwork
                    ? bar.wifiNetwork.name + " " + Math.round(bar.wifiStrength * 100) + "%"
                    : "offline"
            }

            // ── Volume ──────────────────────────────────────────────────
            StatusPill {
                menu: "volume"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)

                readonly property var audio: bar.sink ? bar.sink.audio : null

                glyph: {
                    if (!audio || audio.muted) return String.fromCodePoint(0xf075f);  // md-volume-mute
                    if (audio.volume > 0.5)    return String.fromCodePoint(0xf057e);  // md-volume-high
                    if (audio.volume > 0)      return String.fromCodePoint(0xf0580);  // md-volume-medium
                    return String.fromCodePoint(0xf057f);                             // md-volume-low
                }
                // Muted reads as brackets around the level, which is what the
                // old status line did: the number still says where the volume
                // will come back to when it is unmuted.
                label: {
                    if (!audio) return "--";
                    const percent = Math.round(audio.volume * 100) + "%";
                    return audio.muted ? "(" + percent + ")" : percent;
                }
                alert: audio !== null && audio.muted
                tint: Theme.warm
            }

            // ── Disk ────────────────────────────────────────────────────
            StatusPill {
                glyph: String.fromCodePoint(0xf02ca)  // md-harddisk
                label: bar.diskFree
            }

            // ── Battery ─────────────────────────────────────────────────
            // Present only on machines that have one, which is why this is not
            // a per-machine setting the way the i3status module was: UPower
            // knows whether there is a battery, and a desktop simply gets one
            // fewer pill.
            StatusPill {
                readonly property var battery: UPower.displayDevice
                readonly property bool charging:
                    battery && battery.state === UPowerDeviceState.Charging
                readonly property real level: battery ? battery.percentage : 0

                visible: battery !== null && battery.isPresent

                // MDI has a glyph per tenth. Rounding down rather than to
                // nearest, so a battery that says 20% is never drawn as a
                // fuller cell than it is.
                glyph: {
                    if (!battery) return String.fromCodePoint(0xf0091);  // md-battery-unknown
                    if (level >= 0.995)
                        return String.fromCodePoint(charging ? 0xf0085 : 0xf0079);
                    if (level < 0.10 && !charging)
                        return String.fromCodePoint(0xf0083);            // md-battery-alert

                    const tenth = Math.max(1, Math.floor(level * 10));
                    // The charging glyphs are not one contiguous run — 10 and
                    // 50 and 70 were added later and sit in a different block —
                    // so they are listed rather than computed.
                    const charged = [0, 0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d,
                                     0xf0089, 0xf089e, 0xf008a, 0xf008b];
                    return String.fromCodePoint(
                        charging ? charged[tenth] : 0xf0079 + tenth);
                }

                label: {
                    if (!battery) return "";
                    const percent = Math.round(level * 100) + "%";

                    // Seconds to "h:mm", the way i3status put the estimate in
                    // brackets after the percentage. UPower reports 0 when it
                    // has no estimate yet, which is most of the first minute
                    // after unplugging.
                    const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
                    if (!seconds) return percent;

                    const hours = Math.floor(seconds / 3600);
                    const minutes = Math.floor((seconds % 3600) / 60);
                    return percent + " (" + hours + ":"
                        + String(minutes).padStart(2, "0") + ")";
                }

                // Amber below a quarter. Not red below a tenth — red is what
                // every pill on this bar already is — so the critical case is
                // carried by the glyph switching to the alert cell instead.
                alert: level < 0.25 && !charging
                tint: Theme.warm
            }

            // ── Bluetooth ───────────────────────────────────────────────
            // Carries the name of the connected device when there is one, because "which headset am I
            // actually on" is the question the menu gets opened to answer.
            StatusPill {
                menu: "bluetooth"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)

                glyph: {
                    if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled)
                        return String.fromCodePoint(0xf00b2);  // md-bluetooth-off
                    if (bar.connectedBtDevice)
                        return String.fromCodePoint(0xf00b1);  // md-bluetooth-connect
                    return String.fromCodePoint(0xf00af);      // md-bluetooth
                }

                label: {
                    const device = bar.connectedBtDevice;
                    if (!device) return "";
                    const name = device.deviceName || device.name || device.address;
                    return device.batteryAvailable
                        ? name + " " + Math.round(device.battery * 100) + "%"
                        : name;
                }
            }

            // ── Clock ───────────────────────────────────────────────────
            // Last in the row, where the status line has always ended. A pill
            // with no glyph: the reading is unambiguous on its own, and a
            // clock face next to a clock is decoration.
            StatusPill {
                menu: "clock"
                active: bar.openMenu === menu
                onHoverChanged: hovered => bar.pillHover(menu, hovered)

                label: Qt.formatDateTime(clock.date, "dd.MM. HH:mm")
            }
        }
    }
}
