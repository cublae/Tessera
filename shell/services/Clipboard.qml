pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Clipboard history.
//
// Two backends, chosen at startup:
//
//   - **cliphist**, when it is installed. It owns the storage, dedupes, caps
//     the history and refuses to record offers advertising
//     `x-kde-passwordManagerHint`, so passwords never reach the database.
//   - **wl-clipboard**, otherwise. The shell keeps the history itself, so it
//     still has a working clipboard on a machine with no manager installed.
//
// cliphist does not watch the clipboard on its own; it needs
// `wl-paste --watch cliphist store` running. The shell starts that itself
// unless `clipboard.manageDaemon` is off. Running it twice is harmless:
// cliphist dedupes.
Singleton {
    id: root

    // `cliphist`, `wl-clipboard` or `none`, once the probe has answered.
    property string backend: ""
    readonly property bool available: backend === "cliphist" || backend === "wl-clipboard"

    // Newest first. Each entry is `{ id, preview, image? }`; `image` is
    // `{ type, size, dimensions, bytes }` for a picture.
    property var entries: []

    // Tags the spawned watchers' command lines. A child outlives the shell when
    // the shell is killed rather than asked to quit, and an orphaned watcher
    // keeps writing to the history forever, so startup clears any it finds.
    readonly property string tag: "tessera-clipboard-daemon"

    readonly property var config: Config.c.clipboard

    function reload(): void {
        if (backend === "cliphist") lister.running = true
        else if (backend === "wl-clipboard") entries = history.value.map(e => ({ id: e.id, preview: e.preview }))
    }

    function copy(entry: var): void {
        if (backend === "cliphist") {
            run(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", entry.id])
        } else {
            const saved = history.value.find(e => e.id === entry.id)
            if (saved) copyText(saved.text)
        }
    }

    function clear(): void {
        if (backend === "cliphist") {
            run(["cliphist", "wipe"], () => root.reload())
        } else {
            history.save([])
            reload()
        }
    }

    // Put text on the clipboard. Through `wl-copy`'s stdin rather than its
    // argument list, so a value that begins with a dash is text and not a flag,
    // and a long one does not hit the kernel's argument limit.
    function copyText(text: string): void {
        const process = feeder.createObject(root, { input: text })
        process.running = true
    }

    // Decode one image entry to a file and call back with its path, or "".
    // Files are named by entry id, so an entry shown again costs nothing.
    function decodeImage(entry: var, callback: var): void {
        if (!entry.image) {
            callback("")
            return
        }
        const id = entry.id.split("\t")[0]
        const path = `${Paths.runtime}/clipboard-${id}.${entry.image.type}`
        run(["sh", "-c", "[ -s \"$2\" ] || printf '%s' \"$1\" | cliphist decode > \"$2\"", "sh", entry.id, path],
            ok => callback(ok ? path : ""))
    }

    // -- plumbing -----------------------------------------------------------

    function run(argv: var, done: var): void {
        const process = runner.createObject(root, { command: argv, done: done ?? null })
        process.running = true
    }

    Component {
        id: runner

        Process {
            property var done

            onExited: code => {
                if (done) done(code === 0)
                destroy()
            }
        }
    }

    Component {
        id: feeder

        Process {
            property string input

            command: ["wl-copy"]
            stdinEnabled: true
            onStarted: {
                write(input)
                stdinEnabled = false
            }
            onExited: destroy()
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && echo cliphist || { command -v wl-paste >/dev/null && echo wl-clipboard || echo none; }"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim()
                if (root.backend === "none")
                    console.log("tessera: no clipboard history (neither cliphist nor wl-clipboard found)")
                else
                    console.log(`tessera: clipboard history via ${root.backend}`)
                orphans.running = true
            }
        }
    }

    // Clear anything a previous run left behind before starting our own.
    Process {
        id: orphans

        command: ["pkill", "-f", root.tag]
        onExited: {
            root.watching = root.available
            root.reload()
        }
    }

    property bool watching: false

    // -- cliphist -----------------------------------------------------------

    // cliphist stores text and images through separate watchers; this is the
    // arrangement its own documentation prescribes.
    Process {
        running: root.watching && root.backend === "cliphist" && root.config.manageDaemon && Config.c.modules.clipboard
        command: ["sh", "-c", `exec -a ${root.tag} wl-paste --type text --watch cliphist store`]
    }

    Process {
        running: root.watching && root.backend === "cliphist" && root.config.manageDaemon && Config.c.modules.clipboard
        command: ["sh", "-c", `exec -a ${root.tag} wl-paste --type image --watch cliphist store`]
    }

    // cliphist's stand-in for an image: `[[ binary data 8 KiB png 107x113 ]]`.
    readonly property var binaryPreview: /^\[\[\s*binary data\s+([\d.]+)\s*(\w+)\s+(\w+)\s+(\d+x\d+)\s*\]\]$/
    readonly property var units: ({ B: 1, KiB: 1024, MiB: 1024 * 1024, GiB: 1024 * 1024 * 1024 })

    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(line => line.length > 0).map(line => {
                    // cliphist emits "<id>\t<preview>"; the whole line is the
                    // handle its own `decode` expects on stdin, so it is kept.
                    const tab = line.indexOf("\t")
                    const preview = tab === -1 ? line : line.slice(tab + 1)
                    const match = root.binaryPreview.exec(preview.trim())
                    if (!match) return { id: line, preview }
                    return {
                        id: line,
                        preview,
                        image: {
                            type: match[3],
                            size: `${match[1]} ${match[2]}`,
                            dimensions: match[4],
                            bytes: Number(match[1]) * (root.units[match[2]] ?? 1),
                        },
                    }
                })
            }
        }
    }

    // -- wl-clipboard fallback -----------------------------------------------

    readonly property string skip: "--tessera-skip--"

    // Each new clip arrives as one base64 line, so newlines inside it survive
    // the trip. Offers a password manager has marked are swallowed.
    Process {
        running: root.watching && root.backend === "wl-clipboard" && Config.c.modules.clipboard
        command: ["sh", "-c", `exec -a ${root.tag} wl-paste --type text --watch sh -c '
            if wl-paste --list-types 2>/dev/null | grep -qi x-kde-passwordManagerHint; then
                cat > /dev/null
                printf "%s\\n" "${root.skip}"
            else
                base64 -w0
                printf "\\n"
            fi'`]
        stdout: SplitParser {
            onRead: line => root.record(line.trim())
        }
    }

    JsonFile {
        id: history

        path: root.config.persist ? Paths.cache + "/clipboard.json" : ""
        fallback: []
        onReady: root.reload()
    }

    function collapse(text: string): string {
        const single = text.replace(/\s+/g, " ").trim()
        return single.length > 160 ? single.slice(0, 159) + "…" : single
    }

    function record(payload: string): void {
        if (!payload || payload === skip) return

        const text = decodeUtf8(Qt.atob(payload))
        if (!text.trim()) return

        const id = `${Math.floor(Date.now() / 1000)}-${history.value.length}`
        const rest = history.value.filter(e => e.text !== text)
        const next = [{ id, text, preview: collapse(text) }].concat(rest).slice(0, Math.max(1, config.maxEntries))
        if (config.persist) history.save(next)
        else history.value = next
        reload()
    }

    // `atob` hands back one character per byte; the clipboard is UTF-8.
    function decodeUtf8(bytes: string): string {
        let out = ""
        for (let i = 0; i < bytes.length;) {
            const a = bytes.charCodeAt(i)
            let code
            if (a < 0x80) {
                code = a
                i += 1
            } else if (a >= 0xf0) {
                code = ((a & 0x07) << 18) | ((bytes.charCodeAt(i + 1) & 0x3f) << 12)
                    | ((bytes.charCodeAt(i + 2) & 0x3f) << 6) | (bytes.charCodeAt(i + 3) & 0x3f)
                i += 4
            } else if (a >= 0xe0) {
                code = ((a & 0x0f) << 12) | ((bytes.charCodeAt(i + 1) & 0x3f) << 6) | (bytes.charCodeAt(i + 2) & 0x3f)
                i += 3
            } else {
                code = ((a & 0x1f) << 6) | (bytes.charCodeAt(i + 1) & 0x3f)
                i += 2
            }
            out += String.fromCodePoint(code)
        }
        return out
    }
}
