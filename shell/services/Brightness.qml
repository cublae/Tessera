pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The screen backlight.
//
// Read from sysfs, written through logind: `SetBrightness` on the session
// object is what lets an unprivileged desktop change the backlight without a
// udev rule or a setuid helper, and it is what every GNOME session uses.
//
// sysfs attributes do not report changes through inotify, so the value is
// re-read whenever udev announces a backlight event -- which the kernel sends
// for every change, whoever made it -- rather than polled.
Singleton {
    id: root

    // `intel_backlight`, `amdgpu_bl0`, ... or empty on a machine without one.
    property string device: ""
    property int max: 0
    property int raw: 0

    readonly property bool available: device !== "" && max > 0

    // Normalised to 0..1.
    readonly property real brightness: available ? raw / max : 0

    function set(value: real): void {
        if (!available) return
        const target = Math.round(Math.min(1, Math.max(0.01, value)) * max)
        raw = target
        writer.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", device, String(target)]
        writer.running = true
    }

    // The first device with a non-zero range. Firmware interfaces (`acpi_video0`)
    // and raw ones coexist on some laptops; the kernel lists the raw one first
    // when it is the one that works.
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/max_brightness\" ] && echo \"${d##*/} $(cat \"$d/max_brightness\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [name, max] = line.trim().split(" ")
                    if (name && Number(max) > 0) {
                        root.max = Number(max)
                        root.device = name
                        return
                    }
                }
            }
        }
    }

    FileView {
        id: current

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: root.raw = Number(text().trim()) || 0
    }

    Process {
        running: root.device !== ""
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("change") !== -1) current.reload()
            }
        }
    }

    Process {
        id: writer
    }
}
