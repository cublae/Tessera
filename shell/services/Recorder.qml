pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Screen recording through gpu-screen-recorder.
//
// Recording stops with SIGINT: the recorder finalises the container on
// interrupt, where killing it outright leaves an unplayable file.
//
// Capture goes through the desktop portal by default -- on a session that does
// not hand out direct DRM access it is the only target that works -- and the
// portal session token is kept so the picker appears once, not per recording.
//
// The panel can change the tunables. `config.json` is generated, and under Home
// Manager a symlink into the store, so the shell cannot write a setting back
// where it read it; the panel's choices go to the state directory instead and
// sit on top of the configured values. The one you clicked wins, and the page
// has a way to drop every override and fall back to the config.
Singleton {
    id: root

    property bool available: false
    readonly property bool recording: process.running
    property int elapsed: 0
    property string path: ""

    // The keys the panel may change. Everything else stays config-only.
    readonly property var keys: ["target", "fps", "quality", "codec", "audio"]

    readonly property var overrides: {
        const saved = overridesFile.value
        const result = {}
        if (!saved || typeof saved !== "object" || Array.isArray(saved)) return result
        // Only the keys this owns, at the right type: the file is ours, but it
        // is a file, and a hand-edited one should not reach the command line
        // unchecked.
        for (const key of keys) {
            const value = saved[key]
            if (key === "fps" ? typeof value === "number" && Number.isFinite(value) : typeof value === "string")
                result[key] = value
        }
        return result
    }

    readonly property bool overridden: Object.keys(overrides).length > 0

    // Configured values with the panel's overrides on top.
    readonly property var settings: {
        const configured = Config.c.screenRecord
        return Object.assign({
            target: configured.target,
            fps: configured.fps,
            quality: configured.quality,
            codec: configured.codec,
            audio: configured.audio,
        }, overrides)
    }

    function set(patch: var): void {
        overridesFile.save(Object.assign({}, overrides, patch))
    }

    function reset(): void {
        overridesFile.save({})
    }

    function toggle(): void {
        if (recording) stop()
        else start()
    }

    function timestamp(): string {
        const d = new Date()
        const p = n => String(n).padStart(2, "0")
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`
    }

    function start(): void {
        if (recording || !available) return

        const cfg = settings
        const directory = Config.c.screenRecord.directory || Paths.home + "/Videos"
        path = `${directory}/${timestamp()}.mp4`

        const argv = ["gpu-screen-recorder",
            "-w", cfg.target,
            "-f", String(cfg.fps),
            "-q", cfg.quality,
            "-k", cfg.codec,
            "-o", path,
            "-restore-portal-session", "yes",
            "-portal-session-token-filepath", Paths.config + "/portal-session-token"]
        if (cfg.audio) argv.push("-a", cfg.audio)

        process.command = ["sh", "-c", "mkdir -p \"$1\" && shift && exec \"$@\"", "sh", directory].concat(argv)
        elapsed = 0
        process.running = true
    }

    function stop(): void {
        if (!recording) return
        // SIGINT, not kill: the recorder needs to write the container's index.
        process.signal(2)
    }

    Process {
        id: process

        stderr: SplitParser {
            onRead: line => {
                if (/error/i.test(line)) console.error(`tessera: gpu-screen-recorder: ${line}`)
            }
        }
        onExited: code => {
            root.elapsed = 0
            if (code === 0 || code === 130 || code === 2) console.log(`tessera: recording saved to ${root.path}`)
            else console.error(`tessera: gpu-screen-recorder exited with ${code}`)
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 1000
        onTriggered: root.elapsed += 1
    }

    JsonFile {
        id: overridesFile

        path: Paths.state + "/screen-record.json"
        fallback: ({})
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        onExited: code => root.available = code === 0
    }

    function clock(seconds: int): string {
        return `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`
    }
}
