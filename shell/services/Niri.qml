pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reactive view of the niri compositor.
//
// The protocol is newline-delimited JSON over the unix socket in `$NIRI_SOCKET`.
// A plain request gets one reply line and the connection closes; niri does not
// multiplex, so every request opens its own. `"EventStream"` is the exception:
// niri acknowledges it and then keeps the connection open, replaying the whole
// current state -- `WorkspacesChanged`, `WindowsChanged` and friends -- before
// pushing deltas. There is no separate priming query to race against.
//
// Every mutation funnels through `applyEvent`, which keeps the incremental
// deltas consistent with the wholesale snapshots.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""

    // Workspaces across every output, sorted by output then index.
    property var workspaces: []
    property var windows: []
    property var keyboardLayouts: ({ names: [], current_idx: 0 })
    property bool overviewOpen: false

    // Screencasts the compositor is serving: the compositor's own account of
    // who is capturing the screen, and the only trustworthy one. A portal
    // session, a wlr-screencopy recorder and a video call all end up here.
    property var casts: []

    // True while the event stream is live.
    property bool connected: false

    // At least one screencast actually sending frames. A paused cast -- OBS on
    // a scene without the capture -- exists but is not watching.
    readonly property bool casting: casts.some(cast => cast.is_active)

    // Display name of the active layout, e.g. "English (US)".
    readonly property string keyboardLayout: keyboardLayouts.names[keyboardLayouts.current_idx] ?? ""

    readonly property var focusedWindow: windows.find(w => w.is_focused) ?? null
    readonly property var focusedWorkspace: workspaces.find(w => w.is_focused) ?? null

    // The output holding keyboard focus: where a dropdown summoned by a
    // keybinding should appear.
    readonly property string focusedOutput: focusedWorkspace?.output ?? ""

    // Raw events, for anything that needs variants the service ignores.
    signal event(var event)

    // Reconnect backoff, in milliseconds. The last value repeats indefinitely.
    readonly property var backoff: [250, 500, 1000, 2000, 5000]
    property int retry: 0

    // -- queries -----------------------------------------------------------

    function workspacesOn(output: string): var {
        if (!output) return workspaces
        return workspaces.filter(w => w.output === output)
    }

    function windowsOn(workspace: int): var {
        return windows.filter(w => w.workspace_id === workspace)
    }

    function window(id: int): var {
        return windows.find(w => w.id === id) ?? null
    }

    // -- actions -----------------------------------------------------------

    // Send an action. Failures are logged, never thrown at callers.
    function dispatch(action: var, callback: var): void {
        request({ Action: action }, reply => {
            if (reply === null) console.error(`tessera: niri action failed: ${JSON.stringify(action)}`)
            if (callback) callback(reply)
        })
    }

    function focusWorkspace(id: int): void {
        dispatch({ FocusWorkspace: { reference: { Id: id } } })
    }

    function focusWindow(id: int): void {
        dispatch({ FocusWindow: { id } })
    }

    function switchLayout(): void {
        dispatch({ SwitchLayout: { layout: "Next" } })
    }

    // Issue a one-shot request; `callback` gets the unwrapped `Ok` payload, or
    // null when niri refused or could not be reached.
    function request(payload: var, callback: var): void {
        if (!socketPath) {
            if (callback) callback(null)
            return
        }
        const socket = requestComponent.createObject(root, { payload, callback: callback ?? null })
        socket.connected = true
    }

    Component {
        id: requestComponent

        Socket {
            id: socket

            property var payload
            property var callback
            property bool answered: false

            function finish(reply: var): void {
                if (answered) return
                answered = true
                try {
                    if (callback) callback(reply)
                } finally {
                    connected = false
                    destroy()
                }
            }

            path: root.socketPath

            onConnectedChanged: {
                if (connected) {
                    write(JSON.stringify(payload) + "\n")
                    flush()
                } else {
                    finish(null)
                }
            }

            onError: finish(null)

            parser: SplitParser {
                onRead: line => {
                    let reply = null
                    try {
                        const parsed = JSON.parse(line)
                        if ("Ok" in parsed) reply = parsed.Ok
                        else console.error(`tessera: niri rejected ${JSON.stringify(socket.payload)}: ${parsed.Err}`)
                    } catch (error) {
                        console.error(`tessera: unexpected reply from niri: ${line}`)
                    }
                    socket.finish(reply)
                }
            }
        }
    }

    // -- event stream ------------------------------------------------------

    Socket {
        id: stream

        property bool handshaken: false

        path: root.socketPath
        connected: root.socketPath !== ""

        onConnectedChanged: {
            if (connected) {
                handshaken = false
                write("\"EventStream\"\n")
                flush()
            } else {
                if (root.connected) console.error("tessera: niri event stream dropped")
                root.connected = false
                reconnect.interval = root.backoff[Math.min(root.retry, root.backoff.length - 1)]
                root.retry += 1
                reconnect.restart()
            }
        }

        parser: SplitParser {
            onRead: line => {
                if (!line.trim()) return

                let parsed
                try {
                    parsed = JSON.parse(line)
                } catch (error) {
                    console.error(`tessera: unreadable niri event: ${line}`)
                    return
                }

                // niri acknowledges the subscription before any event arrives.
                if (!stream.handshaken) {
                    stream.handshaken = true
                    if ("Err" in parsed) {
                        console.error(`tessera: niri refused the event stream: ${parsed.Err}`)
                        return
                    }
                    root.retry = 0
                    root.connected = true
                    return
                }

                try {
                    root.applyEvent(parsed)
                } catch (error) {
                    // A malformed or unrecognised event must not tear the stream down.
                    console.error(`tessera: could not handle niri event: ${error}`)
                }
            }
        }
    }

    Timer {
        id: reconnect

        onTriggered: {
            if (root.socketPath && !stream.connected) stream.connected = true
        }
    }

    Component.onCompleted: {
        if (!socketPath) console.error("tessera: NIRI_SOCKET is unset; the niri service will stay disconnected")
    }

    // -- event application -------------------------------------------------

    function setWorkspaces(list: var): void {
        workspaces = list.slice().sort((a, b) => {
            const output = (a.output ?? "").localeCompare(b.output ?? "")
            return output !== 0 ? output : a.idx - b.idx
        })
    }

    function replace(list: var, match: var, change: var): var {
        return list.map(item => match(item) ? Object.assign({}, item, change(item)) : item)
    }

    function applyEvent(ev: var): void {
        const kind = Object.keys(ev)[0]
        const payload = ev[kind]

        switch (kind) {
        case "WorkspacesChanged":
            setWorkspaces(payload.workspaces)
            break

        case "WorkspaceActivated": {
            // Activating a workspace deactivates its siblings on the same output.
            const activated = workspaces.find(w => w.id === payload.id)
            if (!activated) break
            setWorkspaces(workspaces.map(w => {
                if (w.output !== activated.output) {
                    // Focus is exclusive across outputs, activity is not.
                    return payload.focused ? Object.assign({}, w, { is_focused: false }) : w
                }
                const isThis = w.id === payload.id
                return Object.assign({}, w, {
                    is_active: isThis,
                    is_focused: payload.focused ? isThis : w.is_focused && isThis,
                })
            }))
            break
        }

        case "WorkspaceActiveWindowChanged":
            setWorkspaces(replace(workspaces, w => w.id === payload.workspace_id,
                                  () => ({ active_window_id: payload.active_window_id })))
            break

        case "WorkspaceUrgencyChanged":
            setWorkspaces(replace(workspaces, w => w.id === payload.id, () => ({ is_urgent: payload.urgent })))
            break

        case "WindowsChanged":
            windows = payload.windows
            break

        case "WindowOpenedOrChanged": {
            const incoming = payload.window
            const known = windows.some(w => w.id === incoming.id)
            let next = known ? windows.map(w => w.id === incoming.id ? incoming : w) : windows.concat([incoming])

            // niri reports focus on the window itself, so clear the previous holder.
            if (incoming.is_focused)
                next = next.map(w => w.id === incoming.id || !w.is_focused ? w : Object.assign({}, w, { is_focused: false }))
            windows = next
            break
        }

        case "WindowClosed":
            windows = windows.filter(w => w.id !== payload.id)
            break

        case "WindowFocusChanged":
            windows = windows.map(w => w.is_focused === (w.id === payload.id) ? w : Object.assign({}, w, { is_focused: w.id === payload.id }))
            break

        case "WindowUrgencyChanged":
            windows = replace(windows, w => w.id === payload.id, () => ({ is_urgent: payload.urgent }))
            break

        case "WindowLayoutsChanged": {
            const layouts = new Map(payload.changes)
            windows = replace(windows, w => layouts.has(w.id), w => ({ layout: layouts.get(w.id) }))
            break
        }

        case "KeyboardLayoutsChanged":
            keyboardLayouts = payload.keyboard_layouts
            break

        case "KeyboardLayoutSwitched":
            keyboardLayouts = Object.assign({}, keyboardLayouts, { current_idx: payload.idx })
            break

        case "OverviewOpenedOrClosed":
            overviewOpen = payload.is_open
            break

        // Screencasts follow the same shape as windows: one snapshot on connect,
        // deltas from then on. Watching only `CastsChanged` looks right and never
        // fires again, so an indicator built on it stays dark through every capture.
        case "CastsChanged":
            casts = payload.casts
            break

        case "CastStartedOrChanged": {
            const incoming = payload.cast
            const known = casts.some(cast => cast.stream_id === incoming.stream_id)
            casts = known ? casts.map(cast => cast.stream_id === incoming.stream_id ? incoming : cast)
                          : casts.concat([incoming])
            break
        }

        case "CastStopped":
            casts = casts.filter(cast => cast.stream_id !== payload.stream_id)
            break

        default:
            // Unhandled variants still reach subscribers through `event`.
            break
        }

        root.event(ev)
    }
}
