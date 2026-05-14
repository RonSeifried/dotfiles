pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

// Convenience accessors over Quickshell.Networking devices model.
// Avoids duplicating iteration logic in Bar.qml + WifiPanel.qml.
Singleton {
    id: root

    // Re-evaluate on devices model change + per-device state changes.
    readonly property var _devices: Networking.devices

    function _firstByType(t) {
        const m = Networking.devices
        if (!m) return null
        for (let i = 0; i < m.values.length; ++i) {
            const d = m.values[i]
            if (d && d.type === t) return d
        }
        return null
    }

    readonly property var wifiDevice: _firstByType(DeviceType.Wifi)
    readonly property var wiredDevice: _firstByType(DeviceType.Wired)

    readonly property var activeWifi: {
        const d = wifiDevice
        if (!d || !d.connected) return null
        const nets = d.networks
        if (!nets) return null
        for (let i = 0; i < nets.values.length; ++i) {
            const n = nets.values[i]
            if (n && n.connected) return n
        }
        return null
    }

    readonly property bool wiredConnected: wiredDevice && wiredDevice.connected

    // Signal-icon helper: input 0.0..1.0 (qs API) → wifi icon glyph.
    function signalIcon(strength) {
        const pct = (strength || 0) * 100
        if (pct >= 75) return "󰤨"
        if (pct >= 50) return "󰤥"
        if (pct >= 25) return "󰤢"
        return "󰤟"
    }
}
