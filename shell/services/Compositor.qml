pragma Singleton

import QtQuick
import Quickshell

// The compositor the shell is running on, whichever that is.
//
// The rest of the shell only ever talks to this. Each backend publishes the
// same shape -- the one niri's IPC uses, since it is the richer of the two --
// so nothing above this line needs to know which is underneath. A backend is
// only instantiated when it is selected here, so the other one never connects
// or complains about a socket that does not exist.
Singleton {
    id: root

    // A compositor nested in another inherits the outer one's variable as well
    // as setting its own, and so can a systemd environment left over from an
    // earlier session. Only then does XDG_CURRENT_DESKTOP get to break the tie.
    readonly property string name: {
        const hyprland = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
        const niri = Quickshell.env("NIRI_SOCKET") ?? ""
        const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase()
        if (hyprland && (!niri || desktop.includes("hyprland"))) return "hyprland"
        return niri ? "niri" : ""
    }

    readonly property var backend: name === "hyprland" ? HyprlandIpc : name === "niri" ? Niri : null

    readonly property var workspaces: backend?.workspaces ?? []
    readonly property var windows: backend?.windows ?? []
    readonly property var keyboardLayouts: backend?.keyboardLayouts ?? ({ names: [], current_idx: 0 })
    readonly property string keyboardLayout: backend?.keyboardLayout ?? ""
    readonly property var casts: backend?.casts ?? []
    readonly property bool casting: backend?.casting ?? false
    readonly property var focusedWindow: backend?.focusedWindow ?? null
    readonly property string focusedOutput: backend?.focusedOutput ?? ""

    // Whether the compositor can freeze the screen across a theme change.
    readonly property bool canTransition: name === "niri" && backend.connected

    function workspacesOn(output: string): var {
        return backend?.workspacesOn(output) ?? []
    }

    function window(id: var): var {
        return backend?.window(id) ?? null
    }

    function focusWorkspace(id: var): void {
        backend?.focusWorkspace(id)
    }

    function switchLayout(): void {
        backend?.switchLayout()
    }

    function screenshot(): void {
        backend?.screenshot()
    }

    function logOut(): void {
        backend?.logOut()
    }

    // `callback` runs once the compositor has frozen the screen.
    function transition(ms: int, callback: var): void {
        backend.dispatch({ DoScreenTransition: { delay_ms: ms } }, callback)
    }

    Component.onCompleted: {
        if (!name) console.error("tessera: neither HYPRLAND_INSTANCE_SIGNATURE nor NIRI_SOCKET is set; compositor state will stay empty")
    }
}
