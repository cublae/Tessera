pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reactive view of the Hyprland compositor, in the shape `Niri` publishes.
//
// Hyprland has two sockets in `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE`.
// `.socket.sock` takes one command per connection, answers and hangs up.
// `.socket2.sock` streams `EVENT>>DATA` lines, which say that something changed
// but rarely enough to say what the result is -- so a structural event just
// queues a re-read, and only the two that fire constantly (a title, the focus)
// are applied in place.
Singleton {
    id: root

    readonly property string signature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    readonly property string socketDir: signature ? `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr/${signature}` : ""

    property var workspaces: []
    property var windows: []
    property var keyboardLayouts: ({ names: [], current_idx: 0 })

    // Screen captures in progress. Hyprland reports that one started and whether
    // it is of a monitor or a window, but not which, and only while it runs.
    property var casts: []

    // True while the event stream is live.
    property bool connected: false

    readonly property bool casting: casts.length > 0
    readonly property string keyboardLayout: keyboardLayouts.names[keyboardLayouts.current_idx] ?? ""
    readonly property var focusedWindow: windows.find(w => w.is_focused) ?? null
    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null
    readonly property string focusedOutput: focusedWorkspace?.output ?? ""

    // Reconnect backoff, in milliseconds. The last value repeats indefinitely.
    readonly property var backoff: [250, 500, 1000, 2000, 5000]
    property int retry: 0

    // Windows asking for attention. Hyprland announces it once and offers no
    // way to read it back, so this is the only record there is.
    property var urgent: ({})

    property bool refreshing: false
    property bool stale: false

    // Hyprland configured in Lua evaluates what it is asked to dispatch; one
    // still on hyprlang takes `dispatcher args`. Lua is the way forward, so it
    // is tried first and the answer remembered.
    property bool legacyDispatch: false

    // Whether the graceful alternative to the exit dispatcher is installed.
    property bool hasShutdown: false

    // -- queries -----------------------------------------------------------

    function workspacesOn(output: string): var {
        if (!output) return workspaces
        return workspaces.filter(w => w.output === output)
    }

    function window(id: var): var {
        return windows.find(w => w.id === id) ?? null
    }

    // -- actions -----------------------------------------------------------

    // Failures are logged, never thrown at callers.
    function dispatch(lua: string, legacy: string): void {
        request(`/dispatch ${legacyDispatch ? legacy : lua}`, reply => {
            if (reply?.trim() === "ok") return
            // A Lua error quotes the chunk it failed on; anything else means the
            // config language was the wrong guess.
            if (!legacyDispatch && reply !== null && !reply.includes("hl.dispatch")) {
                legacyDispatch = true
                dispatch(lua, legacy)
                return
            }
            console.error(`tessera: Hyprland refused "${legacyDispatch ? legacy : lua}": ${reply}`)
        })
    }

    function focusWorkspace(id: var): void {
        const workspace = workspaces.find(w => w.id === id)
        if (!workspace) return
        const reference = id > 0 ? String(id) : `name:${workspace.name}`
        dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(reference)} })`, `workspace ${reference}`)
    }

    function switchLayout(): void {
        request("/switchxkblayout current next", reply => {
            if (reply?.trim() !== "ok") console.error(`tessera: Hyprland could not switch layout: ${reply}`)
        })
    }

    // Hyprland has no screenshot UI of its own, so this is the usual grim and
    // slurp pair, saving and copying the way niri's does.
    function screenshot(): void {
        if (!shot.running) shot.running = true
    }

    function logOut(): void {
        if (hasShutdown) Quickshell.execDetached(["hyprshutdown"])
        else dispatch("hl.dsp.exit()", "exit")
    }

    Process {
        id: shot

        command: ["sh", "-c", `
            region=$(slurp) || exit 2
            dir="\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
            mkdir -p "$dir" || exit 1
            file="$dir/Screenshot $(date '+%Y-%m-%d %H-%M-%S').png"
            grim -g "$region" "$file" || exit 1
            wl-copy --type image/png < "$file"
        `]

        onExited: code => {
            // Cancelling the selection is a normal outcome and passes silently.
            if (code === 0) Shell.osd({ icon: "camera-photo-symbolic", text: I18n.tr("Screenshot copied") })
            else if (code !== 2) console.error(`tessera: screenshot failed with ${code}`)
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprshutdown"]
        onExited: code => root.hasShutdown = code === 0
    }

    // -- requests ----------------------------------------------------------

    // Issue a one-shot command; `callback` gets the raw reply, or null when
    // Hyprland could not be reached.
    function request(command: string, callback: var): void {
        if (!socketDir) {
            if (callback) callback(null)
            return
        }
        const socket = requestComponent.createObject(root, { command, callback: callback ?? null })
        socket.connected = true
    }

    function query(name: string, callback: var): void {
        request(`j/${name}`, reply => {
            try {
                callback(reply === null ? null : JSON.parse(reply))
            } catch (error) {
                console.error(`tessera: unexpected reply from Hyprland to ${name}: ${reply}`)
                callback(null)
            }
        })
    }

    Component {
        id: requestComponent

        Socket {
            id: socket

            property string command
            property var callback
            property bool answered: false

            function finish(reply: var): void {
                if (answered) return
                answered = true
                try {
                    if (callback) callback(reply)
                } finally {
                    destroy()
                }
            }

            path: `${root.socketDir}/.socket.sock`

            onConnectedChanged: {
                if (connected) {
                    write(command)
                    flush()
                } else {
                    settle()
                }
            }

            // A reply carries no terminator: Hyprland hanging up is the end of it,
            // and arrives as an error like any other. Both land in the middle of
            // the socket's own teardown, which it does not survive being destroyed
            // from, so the reply is only picked up once that has unwound.
            function settle(): void {
                Qt.callLater(() => finish(reply.text || null))
            }

            onError: settle()

            parser: StdioCollector {
                id: reply

                waitForEnd: false
                onStreamFinished: socket.settle()
            }
        }
    }

    // -- state -------------------------------------------------------------

    function refresh(): void {
        if (refreshing) {
            stale = true
            return
        }
        refreshing = true
        stale = false

        const names = ["workspaces", "clients", "monitors", "activeworkspace", "activewindow"]
        const replies = {}
        let pending = names.length
        for (const name of names) {
            query(name, reply => {
                replies[name] = reply
                if (--pending > 0) return
                try {
                    if (names.every(n => replies[n] !== null)) apply(replies)
                } finally {
                    refreshing = false
                    if (stale) refreshTimer.restart()
                }
            })
        }
    }

    // `activewindow` is an empty object when nothing has focus.
    function apply(replies: var): void {
        const clients = replies.clients.filter(c => c.mapped && !c.hidden)
        const activeWindow = replies.activewindow.address ?? ""

        const live = {}
        for (const c of clients) if (urgent[c.address]) live[c.address] = true
        urgent = live

        setWindows(clients.map(c => ({
            id: c.address,
            title: c.title,
            app_id: c.class || c.initialClass,
            // The shell has no use for a scratchpad: what is in one is out of the way.
            workspace_id: isSpecial(c.workspace.name) ? null : c.workspace.id,
            is_focused: c.address === activeWindow,
            is_urgent: !!live[c.address],
        })))

        setWorkspaces(replies.workspaces.filter(w => !isSpecial(w.name)).map(w => ({
            id: w.id,
            // A named workspace has a negative id, which is no use as a label.
            idx: w.id > 0 ? w.id : w.name,
            // Hyprland names unnamed workspaces after their number.
            name: w.name === String(w.id) ? null : w.name,
            output: w.monitor,
            is_active: replies.monitors.some(m => m.activeWorkspace.id === w.id),
            is_focused: w.id === replies.activeworkspace.id,
            is_urgent: clients.some(c => live[c.address] && c.workspace.id === w.id),
        })))
    }

    function isSpecial(name: string): bool {
        return name.startsWith("special:")
    }

    // A refresh mostly finds nothing new, and a new array rebuilds every
    // delegate in the bar, tooltips and all.
    function setWindows(next: var): void {
        if (JSON.stringify(next) !== JSON.stringify(windows)) windows = next
    }

    // Numbered workspaces in order, then named ones, per output.
    function setWorkspaces(next: var): void {
        next.sort((a, b) => {
            const output = (a.output ?? "").localeCompare(b.output ?? "")
            if (output !== 0) return output
            return a.id > 0 && b.id > 0 ? a.id - b.id : b.id - a.id
        })
        if (JSON.stringify(next) !== JSON.stringify(workspaces)) workspaces = next
    }

    // Layouts only come as the codes from the config, `us, ru`, plus the xkb
    // description of the active one -- which is what gets shown, and all that
    // is ever looked at, so the others can stay codes.
    function refreshKeyboard(): void {
        query("devices", devices => {
            const keyboards = devices?.keyboards ?? []
            const main = keyboards.find(k => k.main) ?? keyboards[0]
            if (!main) return
            const names = main.layout.split(",").map(code => code.trim())
            const current_idx = main.active_layout_index
            names[current_idx] = main.active_keymap
            const next = { names, current_idx }
            if (JSON.stringify(next) !== JSON.stringify(keyboardLayouts)) keyboardLayouts = next
        })
    }

    Timer {
        id: refreshTimer

        interval: 30
        onTriggered: root.refresh()
    }

    // -- event stream ------------------------------------------------------

    Socket {
        id: stream

        path: `${root.socketDir}/.socket2.sock`
        connected: root.socketDir !== ""

        onConnectedChanged: {
            if (connected) {
                root.retry = 0
                root.connected = true
                root.refresh()
                root.refreshKeyboard()
            } else {
                if (root.connected) console.error("tessera: Hyprland event stream dropped")
                root.connected = false
                root.casts = []
                reconnect.interval = root.backoff[Math.min(root.retry, root.backoff.length - 1)]
                root.retry += 1
                reconnect.restart()
            }
        }

        parser: SplitParser {
            onRead: line => {
                const split = line.indexOf(">>")
                if (split === -1) return
                try {
                    root.applyEvent(line.slice(0, split), line.slice(split + 2))
                } catch (error) {
                    // A malformed event must not tear the stream down.
                    console.error(`tessera: could not handle Hyprland event ${line}: ${error}`)
                }
            }
        }
    }

    Timer {
        id: reconnect

        onTriggered: {
            if (root.socketDir && !stream.connected) stream.connected = true
        }
    }

    Component.onCompleted: {
        if (!signature) console.error("tessera: HYPRLAND_INSTANCE_SIGNATURE is unset; the Hyprland service will stay disconnected")
    }

    function applyEvent(name: string, data: string): void {
        switch (name) {
        case "workspacev2":
        case "focusedmonv2":
        case "createworkspacev2":
        case "destroyworkspacev2":
        case "moveworkspacev2":
        case "renameworkspace":
        case "openwindow":
        case "closewindow":
        case "movewindowv2":
        case "monitoraddedv2":
        case "monitorremoved":
        case "monitorremovedv2":
            refreshTimer.restart()
            break

        case "configreloaded":
            refreshTimer.restart()
            refreshKeyboard()
            break

        case "activelayout":
            refreshKeyboard()
            break

        // Titles and focus can change many times a second; a spinner in a
        // terminal title should not cost a round trip per frame.
        case "windowtitlev2": {
            const comma = data.indexOf(",")
            const id = `0x${data.slice(0, comma)}`
            const title = data.slice(comma + 1)
            windows = windows.map(w => w.id === id ? Object.assign({}, w, { title }) : w)
            break
        }

        // Empty when nothing has focus.
        case "activewindowv2": {
            const id = data && data !== "," ? `0x${data}` : ""
            windows = windows.map(w => w.is_focused === (w.id === id) ? w : Object.assign({}, w, { is_focused: w.id === id }))
            if (urgent[id]) {
                const next = Object.assign({}, urgent)
                delete next[id]
                urgent = next
                refreshTimer.restart()
            }
            break
        }

        case "urgent":
            urgent = Object.assign({}, urgent, { [`0x${data}`]: true })
            refreshTimer.restart()
            break

        // `STATE,OWNER`, once per client: 1 starts and 0 stops; the owner is 0
        // for a monitor and 1 for a window. A capture that began before the
        // shell did ends without ever having been counted.
        case "screencast": {
            const [state, owner] = data.split(",")
            if (state === "1")
                casts = casts.concat([{ is_active: true, target: owner === "1" ? { Window: { id: null } } : {} }])
            else
                casts = casts.slice(0, -1)
            break
        }
        }
    }
}
