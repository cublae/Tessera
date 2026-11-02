import QtQuick
import qs.services
import qs.components

// The focused window's title; on a side bar, which has no room for one, its icon.
Item {
    id: root

    property var bar

    readonly property var window: Niri.focusedWindow
    readonly property bool shown: window !== null
    readonly property var cfg: Config.c.focusedWindow

    function prettify(appId: string): string {
        if (!appId) return ""
        const last = appId.split(".").pop()
        return last.charAt(0).toUpperCase() + last.slice(1)
    }

    readonly property string text: {
        if (!window) return ""
        const raw = cfg.showAppId ? prettify(window.app_id) : (window.title ?? "")
        const max = cfg.maxLength
        return max > 0 && raw.length > max ? raw.slice(0, Math.max(0, max - 1)).trimEnd() + "…" : raw
    }

    implicitWidth: bar.vertical ? 24 : label.implicitWidth + Theme.spacing * 2
    implicitHeight: 24

    Txt {
        id: label

        visible: !root.bar.vertical
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 600)
        text: root.text
        font.weight: Font.Medium
    }

    Icon {
        visible: root.bar.vertical
        anchors.centerIn: parent
        name: root.window ? Icons.appIcon(root.window.app_id) : Icons.fallbackApp
    }

    Tip {
        text: root.window?.title ?? ""
    }
}
