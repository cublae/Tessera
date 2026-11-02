pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU load, memory use and CPU temperature.
//
// Everything comes from the kernel's own files -- `/proc/stat`, `/proc/meminfo`
// and hwmon -- so this needs no daemon, no library and no permissions. It reads
// only while a bar module is showing it.
//
// Load is a difference between two readings rather than a number the kernel
// keeps, so the first sample has nothing to compare against and reads zero.
Singleton {
    id: root

    // How many modules are showing the readings; polling stops at zero.
    property int watchers: 0

    property real cpu: 0
    property real memory: 0
    // Degrees, or -1 where nothing reports one.
    property int temperature: -1

    property var previous: null
    property string sensor: ""
    property bool sensorSearched: false

    Timer {
        running: root.watchers > 0
        repeat: true
        triggeredOnStart: true
        interval: Math.max(500, Config.c.resources.interval)
        onTriggered: {
            stat.reload()
            meminfo.reload()
            if (root.sensor) thermal.reload()
        }
    }

    // `/proc/stat`'s first line sums all cores, in jiffies since boot: user,
    // nice, system, idle, iowait, irq, softirq, steal. Idle and iowait are the
    // two the CPU was not working.
    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const values = text().split("\n")[0].split(/\s+/).slice(1).map(Number).filter(Number.isFinite)
            if (values.length < 5) return

            const total = values.reduce((sum, v) => sum + v, 0)
            const busy = total - values[3] - values[4]
            const last = root.previous
            root.previous = { busy, total }
            if (!last) return

            const span = total - last.total
            root.cpu = span > 0 ? Math.min(1, Math.max(0, (busy - last.busy) / span)) : 0
        }
    }

    // MemAvailable is the kernel's own estimate of what a new process could get,
    // which is the number a user means by "free" -- caches included.
    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const content = text()
            const field = name => {
                const match = new RegExp(`^${name}:\\s+(\\d+)`, "m").exec(content)
                return match ? Number(match[1]) : 0
            }
            const total = field("MemTotal")
            const available = field("MemAvailable")
            root.memory = total > 0 ? Math.min(1, Math.max(0, (total - available) / total)) : 0
        }
    }

    FileView {
        id: thermal

        path: root.sensor
        printErrors: false
        // Millidegrees, the way every hwmon reports.
        onLoaded: {
            const raw = Number(text().trim())
            root.temperature = Number.isFinite(raw) ? Math.round(raw / 1000) : -1
        }
    }

    // hwmon numbering is not stable across boots, so the sensor is found by
    // name, most specific first; the first thermal zone is a poor guess but a
    // guess.
    Process {
        running: root.watchers > 0 && !root.sensorSearched
        command: ["sh", "-c", `
            for want in k10temp zenpower coretemp cpu_thermal acpitz; do
                for d in /sys/class/hwmon/*; do
                    [ "$(cat "$d/name" 2>/dev/null)" = "$want" ] && [ -r "$d/temp1_input" ] && { echo "$d/temp1_input"; exit 0; }
                done
            done
            [ -r /sys/class/thermal/thermal_zone0/temp ] && echo /sys/class/thermal/thermal_zone0/temp`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sensorSearched = true
                root.sensor = text.trim()
            }
        }
    }
}
