pragma Singleton

import QtQuick
import Quickshell

// Icon names that differ between themes.
//
// Names are not as portable as the freedesktop spec suggests. Adwaita has no
// plain `notification-symbolic` and keeps the bell under its Settings-panel
// name, while Tela, Papirus and Breeze ship the plain one. Picking a single name
// means a missing-image square on half the systems, so the theme is asked and
// the first name it actually has wins.
Singleton {
    id: root

    readonly property string fallbackApp: "application-x-executable"

    // First name the theme has, or the last one as a last resort.
    function first(names: var): string {
        for (const name of names) {
            if (name && Quickshell.iconPath(name, true) !== "") return name
        }
        return names[names.length - 1] ?? ""
    }

    // A source for an `Image`, from what a desktop entry, a window or a stream
    // calls its icon. `Icon=` is a themed name *or* an absolute path -- the spec
    // allows both, and Steam games and AppImages use the path form. `foo.png`
    // in an entry usually means the themed icon `foo`.
    function source(icon: string, fallback: string): string {
        const name = (icon ?? "").trim()
        if (name.startsWith("/")) return "file://" + name
        if (name.startsWith("file://") || name.startsWith("image://")) return name

        for (const candidate of [name, name.replace(/\.(png|svg|xpm)$/i, "")]) {
            if (!candidate) continue
            const path = Quickshell.iconPath(candidate, true)
            if (path) return path
        }
        return Quickshell.iconPath(fallback || fallbackApp, true)
    }

    // Best icon for a window's app id. The desktop entry is authoritative, but
    // plenty of applications ship an icon named after their app id with no
    // matching entry, so the theme is asked directly before giving up:
    // `org.gnome.Nautilus` -> `nautilus`.
    function appIcon(appId: string): string {
        if (!appId) return fallbackApp
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry?.icon) return entry.icon

        const key = appId.toLowerCase()
        const tail = key.split(".").pop()
        return first([appId, key, tail, fallbackApp])
    }

    function bell(quiet: bool): string {
        return quiet ? first(["notification-disabled-symbolic", "notifications-disabled-symbolic"])
                     : first(["notification-symbolic", "preferences-system-notifications-symbolic"])
    }

    // Tela ships a `list-add-symbolic` that loads and then draws as nothing,
    // while its plain `list-add` is fine; Adwaita has only the symbolic one.
    function add(): string {
        return first(["list-add", "list-add-symbolic"])
    }
}
