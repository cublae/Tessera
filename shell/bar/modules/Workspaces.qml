import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// The workspaces, with an icon per window; click to focus, scroll to cycle.
GridLayout {
    id: root

    property var bar

    readonly property var cfg: Config.c.workspaces

    columns: bar.vertical ? 1 : -1
    columnSpacing: 2
    rowSpacing: 2

    readonly property var shownWorkspaces: cfg.perMonitor ? Compositor.workspacesOn(bar.output) : Compositor.workspaces

    readonly property var byWorkspace: {
        const map = {}
        for (const w of Compositor.windows) {
            if (w.workspace_id === null) continue
            ;(map[w.workspace_id] = map[w.workspace_id] ?? []).push(w)
        }
        return map
    }

    // niri always keeps one empty workspace spare, so empty ones are left out
    // unless asked for; the active one is shown either way.
    readonly property var items: shownWorkspaces
        .filter(w => cfg.showEmpty || byWorkspace[w.id] || w.is_active)
        .map(w => ({ workspace: w, windows: byWorkspace[w.id] ?? [] }))

    function label(w: var): string {
        if (cfg.labels === "none") return ""
        if (cfg.labels === "name") return w.name ?? String(w.idx)
        return String(w.idx)
    }

    function tooltip(w: var, windows: var): string {
        const name = w.name ?? `${I18n.tr("Workspace")} ${w.idx}`
        if (windows.length === 0) return name
        const titles = windows.slice(0, 6)
            .map(x => x.title || x.app_id || I18n.tr("Untitled"))
            .map(t => t.length > 44 ? t.slice(0, 43) + "…" : t)
        const more = windows.length > titles.length ? `\n${I18n.tr("…and")} ${windows.length - titles.length} ${I18n.tr("more")}` : ""
        return `${name}\n${titles.join("\n")}${more}`
    }

    function cycle(direction: int): void {
        const list = cfg.perMonitor ? Compositor.workspacesOn(bar.output) : Compositor.workspaces
        const current = list.findIndex(w => w.is_active)
        if (current === -1) return
        const next = list[current + direction]
        if (next) Compositor.focusWorkspace(next.id)
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta !== 0) root.cycle(delta < 0 ? 1 : -1)
        }
    }

    Repeater {
        model: root.items

        Button {
            id: button

            required property var modelData
            readonly property var w: modelData.workspace
            readonly property bool empty: modelData.windows.length === 0

            vertical: root.bar.vertical
            padding: 4
            spacing: 3
            minHeight: 24
            radius: Theme.radiusSm
            implicitWidth: Math.max(w.is_focused ? 34 : 24, contentWidth)
            opacity: empty && !w.is_active && !w.is_focused ? 0.45 : 1
            tooltip: root.tooltip(w, modelData.windows)

            color: {
                if (w.is_focused) return Theme.accentBg
                if (w.is_urgent) return Theme.alpha(Theme.destructive, 0.2)
                if (w.is_active) return Theme.alpha(Theme.accent, 0.15)
                return pressed ? activeColor : hovered ? hoverColor : "transparent"
            }

            readonly property color ink: w.is_focused ? Theme.accentFg : w.is_urgent ? Theme.destructive : w.is_active ? Theme.accent : Theme.fg

            onClicked: Compositor.focusWorkspace(w.id)

            Txt {
                visible: text !== ""
                text: root.label(button.w)
                color: button.ink
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.cfg.showIcons ? button.modelData.windows.slice(0, Math.max(0, root.cfg.maxIcons)) : []

                Icon {
                    required property var modelData

                    name: Icons.appIcon(modelData.app_id)
                    size: 14
                    opacity: button.w.is_focused ? 0.95 : 0.8
                }
            }
        }
    }
}
