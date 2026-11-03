pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.components

// The freedesktop notification daemon.
//
// Only one process may own `org.freedesktop.Notifications`. If another shell
// already holds it the server simply never receives anything, so an empty list
// is a legitimate state rather than a bug -- and `modules.notifications` is the
// switch for leaving the name to someone else.
Singleton {
    id: root

    readonly property bool enabled: Config.c.modules.notifications

    // Newest first.
    readonly property var server: loader.item
    readonly property var list: server ? server.trackedNotifications.values.slice().sort((a, b) => time(b) - time(a)) : []
    readonly property int count: list.length

    // Do not disturb: popups are held back, the notifications themselves kept.
    // Either the config or the toggle silences them; the toggle persists.
    readonly property bool dnd: Config.c.notifications.doNotDisturb || dndFile.value.on === true

    function setDnd(on: bool): void {
        dndFile.save({ on })
    }

    // Every notification shown as a popup arrives here; the popup windows listen.
    signal arrived(var notification)

    // When each notification came in, by id. The protocol carries no timestamp,
    // and the centre wants to say "5 minutes ago".
    property var times: ({})

    function time(n: var): real {
        return times[n.id] ?? 0
    }

    function dismissAll(): void {
        if (!server) return
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
    }

    // An image for the card: the notification's own picture, else the sending
    // application's icon, else the desktop entry's.
    // `notify-send -i` arrives wrapped as `image://icon/VALUE`, whether VALUE is a
    // themed name or a file. Given a path the icon provider finds nothing and draws
    // its magenta placeholder, so the two are told apart here.
    function iconRequest(n: var): string {
        const image = n.image ?? ""
        return image.startsWith("image://icon/") ? image.slice("image://icon/".length) : ""
    }

    // What to load as the notification's picture, or "".
    function pictureOf(n: var): string {
        const requested = iconRequest(n)
        if (!requested) return n.image ?? ""
        if (!requested.startsWith("/")) return ""
        return "file://" + requested.split("/").map(encodeURIComponent).join("/")
    }

    function appIconOf(n: var): string {
        const requested = iconRequest(n)
        return n.appIcon || (requested.startsWith("/") ? "" : requested) || n.desktopEntry || ""
    }

    JsonFile {
        id: dndFile

        path: Paths.state + "/do-not-disturb.json"
        fallback: ({ on: false })
    }

    // Built only when wanted: constructing the server is what claims the bus name.
    LazyLoader {
        id: loader

        active: root.enabled

        NotificationServer {
            // Kept across a reload of the QML, so `tessera reload` does not throw
            // away what has not been read.
            keepOnReload: true
            actionsSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: false
            imageSupported: true
            persistenceSupported: true

            onNotification: n => {
                if (!root.enabled) return

                n.tracked = true
                const times = Object.assign({}, root.times)
                times[n.id] = Date.now()
                root.times = times

                n.closed.connect(() => {
                    const next = Object.assign({}, root.times)
                    delete next[n.id]
                    root.times = next
                })

                root.arrived(n)
            }
        }
    }
}
