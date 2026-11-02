import QtQuick
import qs.services
import qs.components

// Visible only while something captures the screen -- a call, OBS, a portal.
//
// The source is the compositor rather than a process list: niri knows every
// cast it serves and whether frames are actually flowing.
Button {
    id: root

    property var bar

    readonly property bool shown: Niri.casting

    function describe(cast: var): string {
        if (cast.target.Output) return `${I18n.tr("screen")} ${cast.target.Output.name}`
        if (cast.target.Window) {
            const window = Niri.window(cast.target.Window.id)
            const name = window?.title || window?.app_id
            return name ? `${I18n.tr("window")} “${name}”` : I18n.tr("a window")
        }
        return I18n.tr("the screen")
    }

    tooltip: {
        const active = Niri.casts.filter(cast => cast.is_active)
        if (active.length === 0) return ""
        const what = active.map(describe).filter((x, at, all) => all.indexOf(x) === at).join(", ")
        return active.length === 1 ? `${I18n.tr("Capturing")} ${what}` : `${active.length} ${I18n.tr("captures")}: ${what}`
    }

    // `screen-shared-symbolic` is GNOME's name for exactly this, and it draws a
    // screen; `camera-video-symbolic` was the obvious guess and the wrong one.
    Icon {
        name: Icons.first(["screen-shared-symbolic", "video-display-symbolic"])
        color: Theme.warning
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: Theme.warning
    }
}
