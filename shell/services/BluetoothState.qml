pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ, through Quickshell's client.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connectedDevice: devices.find(d => d.connected) ?? null

    // A device that has not told us its name reports its address, dashes for
    // colons, as one. That is not a name, and an unnamed device nobody has
    // paired is a neighbour's, not something to list.
    function name(device: var): string {
        const placeholder = (device.address ?? "").replace(/:/g, "-").toUpperCase()
        for (const candidate of [device.name, device.deviceName]) {
            const value = (candidate ?? "").trim()
            if (value && value.toUpperCase() !== placeholder) return value
        }
        return ""
    }

    function toggle(): void {
        if (adapter) adapter.enabled = !adapter.enabled
    }
}
