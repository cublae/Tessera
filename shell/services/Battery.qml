pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery state, from UPower when it is running and from sysfs when it is not.
//
// UPower is the richer source -- it normalises states, estimates time remaining
// and resolves an icon -- but it is a daemon a system may simply not run. The
// kernel always exposes the built-in battery under /sys/class/power_supply, so
// that is the fallback and the shell shows a battery either way.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool upower: device?.ready && device.isLaptopBattery && device.isPresent

    // sysfs readings, used only when UPower has nothing.
    property string sysfsPath: ""
    property real sysfsPercentage: 0
    property string sysfsState: "unknown"
    property int sysfsTime: 0

    readonly property string backend: upower ? "upower" : sysfsPath ? "sysfs" : "none"
    readonly property bool available: backend !== "none"

    // Charge level, 0..1.
    readonly property real percentage: upower ? device.percentage : sysfsPercentage

    // `charging`, `discharging`, `full`, `not-charging` or `unknown`.
    readonly property string state: {
        if (!upower) return sysfsState
        switch (device.state) {
        case UPowerDeviceState.Charging:
            return "charging"
        case UPowerDeviceState.Discharging:
            return "discharging"
        case UPowerDeviceState.FullyCharged:
            return "full"
        case UPowerDeviceState.PendingCharge:
            return "not-charging"
        default:
            return "unknown"
        }
    }

    readonly property bool charging: state === "charging"
    readonly property bool discharging: state === "discharging"

    // Seconds until empty, or until full while charging. 0 when unknown.
    readonly property int timeRemaining: upower ? (charging ? device.timeToFull : device.timeToEmpty) : sysfsTime

    readonly property string iconName: upower && device.iconName ? device.iconName : icon(percentage, state)

    // Adwaita's battery icons come in 10% steps, with `-charging-`, `-plugged-in-`
    // and plain variants. `plugged-in` is the right one for the "on AC but not
    // charging" state a laptop with a charge threshold spends most of its life in.
    function icon(fraction: real, state: string): string {
        const level = Math.min(100, Math.max(0, Math.round(fraction * 10) * 10))
        if (state === "full") return "battery-level-100-charged-symbolic"
        if (state === "charging")
            return level >= 100 ? "battery-level-100-charged-symbolic" : `battery-level-${level}-charging-symbolic`
        if (state === "not-charging") return `battery-level-${level}-plugged-in-symbolic`
        return `battery-level-${level}-symbolic`
    }

    function tooltip(): string {
        const level = `${Math.round(percentage * 100)}%`
        if (state === "charging") return `${level} · ${I18n.tr("charging")}`
        if (state === "not-charging") return `${level} · ${I18n.tr("plugged in")}`
        if (state === "full") return `${level} · ${I18n.tr("full")}`
        return level
    }

    // Whether power-profiles-daemon is on the bus. Quickshell reports a
    // profile either way, so the tile asks the bus directly before it claims
    // to switch anything.
    property bool profilesAvailable: false

    Process {
        running: true
        command: ["busctl", "--system", "status", "net.hadess.PowerProfiles"]
        onExited: code => root.profilesAvailable = code === 0
    }

    // -- sysfs --------------------------------------------------------------

    // Battery percentage moves slowly; a slow poll is invisible to the user.
    Timer {
        running: !root.upower
        repeat: true
        triggeredOnStart: true
        interval: 15000
        onTriggered: sysfs.running = true
    }

    // One process reads every attribute of the first real battery, so a poll is
    // a single fork rather than one per file.
    Process {
        id: sysfs

        command: ["sh", "-c", `
            for d in /sys/class/power_supply/*; do
                [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
                [ -r "$d/capacity" ] || continue
                echo "path=$d"
                for f in capacity status charge_now energy_now current_now power_now charge_full energy_full; do
                    [ -r "$d/$f" ] && echo "$f=$(cat "$d/$f")"
                done
                exit 0
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.readSysfs(text)
        }
    }

    function readSysfs(text: string): void {
        const values = {}
        for (const line of text.split("\n")) {
            const at = line.indexOf("=")
            if (at > 0) values[line.slice(0, at)] = line.slice(at + 1).trim()
        }
        if (!values.path || values.capacity === undefined) {
            sysfsPath = ""
            return
        }

        const states = {
            "Charging": "charging",
            "Discharging": "discharging",
            "Full": "full",
            // Reported by laptops that stop charging at a configured threshold.
            "Not charging": "not-charging",
        }

        sysfsPath = values.path
        sysfsPercentage = Number(values.capacity) / 100
        sysfsState = states[values.status] ?? "unknown"

        // Batteries report either charge/current (Ah) or energy/power (Wh); both
        // divide to hours. The rate reads zero whenever the battery is idle.
        const now = Number(values.charge_now ?? values.energy_now)
        const rate = Number(values.current_now ?? values.power_now)
        const full = Number(values.charge_full ?? values.energy_full)
        if (!now || !rate || rate <= 0) sysfsTime = 0
        else if (sysfsState === "discharging") sysfsTime = Math.round(now / rate * 3600)
        else if (sysfsState === "charging" && full > now) sysfsTime = Math.round((full - now) / rate * 3600)
        else sysfsTime = 0
    }
}
