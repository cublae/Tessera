pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper, and the accent colour worth taking from it.
//
// Wayland has no protocol for the wallpaper and no compositor owns it: it is
// just another program painting a background layer. So there is nothing to
// query, only places to look, in order of how far they can be trusted -- an
// explicit `theme.wallpaper`, then waypaper's config, then `swww query`.
//
// "Dominant colour" is the wrong target for an accent. The largest area of a
// photograph is usually sky, wall or shadow, and an accent made of those is a
// grey smear indistinguishable from the panel. What is wanted is the most
// *present* colour that is also worth using as one -- so the picture is
// quantised into equally populated clusters and their hues vote weighted by
// how saturated they are. The winner is forced into a band that carries white
// text: bright enough not to be mud, dark enough not to lose the label on it.
Singleton {
    id: root

    readonly property bool wanted: Config.c.theme.accentFromWallpaper
    readonly property string configured: Config.c.theme.wallpaper.trim()

    property string fromWaypaper: ""
    property string fromSwww: ""

    readonly property string path: {
        if (configured) return expand(configured)
        return fromWaypaper || fromSwww
    }

    function expand(file: string): string {
        return file.startsWith("~/") ? Quickshell.env("HOME") + file.slice(1) : file
    }

    onPathChanged: {
        if (wanted && !path) console.log("tessera: accentFromWallpaper is on but no wallpaper was found")
    }

    FileView {
        path: root.wanted && !root.configured
              ? (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/waypaper/config.ini"
              : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const match = /^\s*wallpaper\s*=\s*(.+?)\s*$/m.exec(text())
            root.fromWaypaper = match ? root.expand(match[1]) : ""
        }
        onLoadFailed: root.fromWaypaper = ""
    }

    // `swww query` prints one line per output ending in the image path. Several
    // outputs can carry different pictures; the first is as good as any, since
    // the accent is one colour for the whole shell either way. swww keeps the
    // answer in a daemon with nothing to subscribe to, so it is asked once.
    Process {
        running: root.wanted && !root.configured
        command: ["swww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = /image:\s*(.+?)\s*$/m.exec(text)
                root.fromSwww = match ? match[1] : ""
            }
        }
    }

    ColorQuantizer {
        id: quantizer

        source: root.wanted && root.path ? "file://" + root.path : ""
        depth: 5
        rescaleSize: 96

        onColorsChanged: Theme.wallpaperAccent = root.pick(colors)
    }

    onWantedChanged: {
        if (!wanted) Theme.wallpaperAccent = null
    }

    // Hue buckets: 24 gives 15° each, which keeps orange and yellow apart.
    readonly property int buckets: 24

    function clamp(value: real, low: real, high: real): real {
        return Math.min(high, Math.max(low, value))
    }

    // Null is a real answer, not a failure: a greyscale wallpaper has no accent
    // to offer and the configured one should stand.
    function pick(colors: var): var {
        const weight = new Array(buckets).fill(0)
        const count = new Array(buckets).fill(0)
        const sumH = new Array(buckets).fill(0)
        const sumS = new Array(buckets).fill(0)
        const sumV = new Array(buckets).fill(0)

        for (const c of colors) {
            const h = c.hsvHue
            const s = c.hsvSaturation
            const v = c.hsvValue
            // Below this saturation a pixel carries no hue worth voting with;
            // near-black and near-white hue is noise.
            if (h < 0 || s < 0.18 || v < 0.15 || v > 0.97) continue

            const bucket = Math.min(buckets - 1, Math.floor(h * buckets))
            weight[bucket] += s
            count[bucket] += 1
            sumH[bucket] += h
            sumS[bucket] += s
            sumV[bucket] += v
        }

        let best = -1
        let bestWeight = 0
        for (let bucket = 0; bucket < buckets; bucket++) {
            if (weight[bucket] > bestWeight) {
                bestWeight = weight[bucket]
                best = bucket
            }
        }
        if (best < 0) return null

        // The bucket's own averages, not its centre: fifteen degrees is the
        // difference between a sky blue and a cyan, and it shows.
        const n = count[best]
        const accent = Qt.hsva(sumH[best] / n, clamp(sumS[best] / n, 0.45, 0.92), clamp(sumV[best] / n, 0.45, 0.82), 1)
        return accent.toString()
    }
}
