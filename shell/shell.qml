//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import "bar"
import "popups"
import "notifications"
import "osd"
import "desktop"
import "picker"

// Tessera -- a desktop shell for niri and Hyprland.
//
// Per-output surfaces -- the bar, notification popups, the overlay, the
// desktop widgets -- are built for every output, or the first one only when
// `bar.onAllMonitors` is off, and follow outputs as they come and go. Dropdowns
// exist once and appear on the output that asked for them.
//
// A second `tessera <command>` never starts a second shell: it is a client of
// the IpcHandler below, and fails with "not running" when there is nothing to
// talk to.
ShellRoot {
    id: root

    readonly property var screens: Config.c.bar.onAllMonitors ? Quickshell.screens : Quickshell.screens.slice(0, 1)

    // Singletons are built on first use; these have to run whether or not
    // anything on screen reads them yet.
    Component.onCompleted: {
        Paths.state
        Audio.maxVolume
        Wallpaper.path
        Clipboard.backend
        Notifs.enabled
    }

    Variants {
        model: Config.c.bar.enabled ? root.screens : []

        Bar {}
    }

    Variants {
        model: Config.c.modules.notifications ? root.screens : []

        NotificationPopups {}
    }

    Variants {
        model: Config.c.modules.osd ? root.screens : []

        Osd {}
    }

    Variants {
        model: Config.c.desktop.enabled ? root.screens : []

        Desktop {}
    }

    Variants {
        model: Picker.active ? Quickshell.screens : []

        ColorPicker {}
    }

    CalendarPopup {}

    LazyLoader {
        active: Config.c.modules.controlCenter
        ControlCenter {}
    }

    LazyLoader {
        active: Config.c.modules.notifications
        NotificationCenter {}
    }

    LazyLoader {
        active: Config.c.modules.launcher
        Launcher {}
    }

    LazyLoader {
        active: Config.c.modules.clipboard
        ClipboardPopup {}
    }

    LazyLoader {
        active: Weather.configured
        WeatherPopup {}
    }

    IpcHandler {
        target: "tessera"

        // Dropdowns go through the same path as a click on the bar, including
        // closing whichever was open.
        function toggle(name: string): string {
            if (Shell.popups.indexOf(name) === -1) return `no window named "${name}"`
            if (!Shell.toggle(name, null)) return `${name} is not built`
            return `toggled ${name}`
        }

        // `tessera control-center wifi` opens straight onto the network list,
        // so a keybinding need not land on the main panel first.
        function controlCenter(page: string): string {
            const pages = ["main", "wifi", "bluetooth", "mixer", "mixer-input", "record", "session"]
            if (pages.indexOf(page) === -1) return `unknown page: ${page}`
            if (!Shell.show("control-center", null)) return "control center is not built"
            Shell.ccPage = page
            return "control center: " + page
        }

        // `edit` toggles; `on` and `off` are for a binding that only ever
        // does one thing.
        function desktop(action: string): string {
            if (action === "on") DesktopLayout.editing = true
            else if (action === "off") DesktopLayout.editing = false
            else if (action === "edit") DesktopLayout.editing = !DesktopLayout.editing
            else return "usage: desktop [edit|on|off]"
            if (DesktopLayout.editing) Shell.close()
            return `desktop editing: ${DesktopLayout.editing}`
        }

        // Answers straight away rather than after the click: the picker stays
        // up until the user is done with it, and a keybinding that blocks its
        // own reply for a minute looks hung.
        function pickColor(): string {
            Shell.close()
            Picker.pick()
            return "picking"
        }

        function reload(): string {
            Config.reload()
            return "reloaded"
        }

        function windows(): string {
            const names = []
            for (const screen of root.screens) {
                if (Config.c.bar.enabled) names.push(`bar-${screen.name}`)
                if (Config.c.desktop.enabled) names.push(`desktop-${screen.name}`)
                if (Config.c.modules.osd) names.push(`osd-${screen.name}`)
                if (Config.c.modules.notifications) names.push(`notification-popups-${screen.name}`)
            }
            for (const popup of Shell.popups) {
                if (Shell.available(popup)) names.push(Shell.open === popup ? `${popup} (open)` : popup)
            }
            return names.join("\n")
        }

        function quit(): string {
            Qt.callLater(Qt.quit)
            return "bye"
        }
    }
}
