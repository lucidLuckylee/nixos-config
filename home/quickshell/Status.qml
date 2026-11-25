// Device state and status glyphs shared by the bar pills and their menus.

pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire

Singleton {
    // PipeWire audio values stay at their stubs until the node is tracked.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink ? sink.audio : null

    readonly property var wifiDevice:
        Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiLive: wifiDevice !== null && Networking.wifiEnabled
    readonly property var wifiNetwork:
        wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btLive: btAdapter !== null && btAdapter.enabled
    readonly property var btConnected:
        btAdapter ? (btAdapter.devices.values.find(d => d.connected) ?? null) : null

    function md(code) {
        return String.fromCodePoint(code);
    }

    // Accept either fractional or percentage signal strength.
    function strength(network) {
        const raw = network ? network.signalStrength : 0;
        return raw > 1 ? raw / 100 : raw;
    }

    function wifiGlyph(fraction) {
        if (fraction > 0.75) return md(0xf0928);
        if (fraction > 0.5)  return md(0xf0925);
        if (fraction > 0.25) return md(0xf0922);
        return md(0xf091f);                       // md-wifi-strength-1..4
    }

    function volumeGlyph(audio) {
        if (!audio || audio.muted) return md(0xf075f);  // md-volume-mute
        if (audio.volume > 0.5)    return md(0xf057e);  // md-volume-high
        if (audio.volume > 0)      return md(0xf0580);  // md-volume-medium
        return md(0xf057f);                             // md-volume-low
    }

    function volumeText(audio) {
        if (!audio) return "--";
        const percent = Math.round(audio.volume * 100) + "%";
        return audio.muted ? "(" + percent + ")" : percent;
    }

    function deviceName(device) {
        return device.deviceName || device.name || device.address;
    }
}
