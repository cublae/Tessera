pragma Singleton

import QtQuick
import Quickshell

// What the windows share: which dropdown is open, on which screen, and the
// overlay's message bus.
//
// Dropdowns are exclusive -- opening one closes whichever was open -- so a
// keybinding behaves exactly like a click on the bar.
Singleton {
    id: root

    readonly property var popups: ["calendar", "control-center", "launcher", "clipboard", "notification-center", "weather"]

    // The open dropdown's name, or "".
    property string open: ""

    // Where the open dropdown appears: the screen of the bar that was clicked,
    // or the one the compositor says has focus when a keybinding asked.
    property var screen: null

    // The page the control center shows: `main`, `wifi`, `bluetooth`, ...
    property string ccPage: "main"

    // Whether `name` would be built at all with the current config.
    function available(name: string): bool {
        const modules = Config.c.modules
        switch (name) {
        case "control-center": return modules.controlCenter
        case "notification-center": return modules.notifications
        case "launcher": return modules.launcher
        case "clipboard": return modules.clipboard && Clipboard.available
        case "weather": return Weather.configured
        case "calendar": return true
        }
        return false
    }

    function focusedScreen(): var {
        const name = Compositor.focusedOutput
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null
    }

    function toggle(name: string, onScreen: var): bool {
        if (!available(name)) return false
        if (open === name) {
            close()
            return true
        }
        screen = onScreen ?? focusedScreen()
        if (name === "control-center") ccPage = "main"
        open = name
        return true
    }

    function show(name: string, onScreen: var): bool {
        if (!available(name)) return false
        if (open !== name) screen = onScreen ?? focusedScreen()
        open = name
        return true
    }

    function close(): void {
        open = ""
    }

    // -- overlay ------------------------------------------------------------

    // `{ icon, level }` or `{ icon, text, swatch? }`; every Osd window listens.
    signal osd(var message)
}
