pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager, through Quickshell's own client.
//
// What a panel needs: which link is carrying traffic, the networks in range,
// and the three things you do with one -- join, leave, forget. A network that
// is never advertised cannot be joined from a scan, so that one goes through
// nmcli, which is NetworkManager's own client and already on the machine.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null

    readonly property bool wifiEnabled: Networking.wifiEnabled

    // The network the Wi-Fi device is on, or null.
    readonly property var activeNetwork: wifi?.networks.values.find(n => n.connected) ?? null

    // `wired`, `wifi` or `none`: whichever link is up, wired first, the way
    // NetworkManager itself prefers it.
    readonly property string primary: wired ? "wired" : activeNetwork ? "wifi" : "none"

    readonly property string ssid: activeNetwork?.name ?? ""
    readonly property real strength: activeNetwork?.signalStrength ?? 0

    function strengthIcon(value: real): string {
        const percent = value * 100
        if (percent > 80) return "network-wireless-signal-excellent-symbolic"
        if (percent > 55) return "network-wireless-signal-good-symbolic"
        if (percent > 30) return "network-wireless-signal-ok-symbolic"
        if (percent > 5) return "network-wireless-signal-weak-symbolic"
        return "network-wireless-signal-none-symbolic"
    }

    readonly property string icon: {
        if (primary === "wired") return "network-wired-symbolic"
        if (primary === "wifi") return strengthIcon(strength)
        if (wifi && !wifiEnabled) return "network-wireless-disabled-symbolic"
        return "network-offline-symbolic"
    }

    readonly property string tooltip: {
        if (primary === "wired") return I18n.tr("Wired")
        if (primary === "wifi") return `${ssid} · ${Math.round(strength * 100)}%`
        return I18n.tr("Offline")
    }

    function secured(network: var): bool {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown
    }

    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on
    }

    // Scanning costs radio time and battery, so it runs only while someone is
    // looking at the list -- the page turns it on and off.
    function setScanning(on: bool): void {
        if (wifi) wifi.scannerEnabled = on
    }

    function connectHidden(ssid: string, password: string): void {
        const argv = ["nmcli", "device", "wifi", "connect", ssid, "hidden", "yes"]
        if (password) argv.push("password", password)
        hidden.command = argv
        hidden.running = true
    }

    Process {
        id: hidden

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) console.error(`tessera: could not join a hidden network: ${text.trim()}`)
            }
        }
    }
}
