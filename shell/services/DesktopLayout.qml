pragma Singleton

import QtQuick
import Quickshell
import qs.components

// Where the desktop widgets sit, per output.
//
// Arranged with the mouse rather than the config: a position is a point on a
// coarse grid over the output, plus a scale and which side of the point the
// widget hangs from. The grid keeps a layout meaningful across resolutions and
// makes two widgets line up without pixel-pushing.
Singleton {
    id: root

    readonly property int columns: 24
    readonly property int rows: 16
    readonly property real minScale: 0.5
    readonly property real maxScale: 3

    property bool editing: false

    readonly property var defaults: ({
        clock: { column: 12, row: 6, scale: 1, anchor: "center" },
        date: { column: 12, row: 7, scale: 1, anchor: "center" },
        media: { column: 12, row: 8, scale: 1, anchor: "center" },
    })

    function clampScale(scale: real): real {
        if (!Number.isFinite(scale)) return 1
        return Math.min(maxScale, Math.max(minScale, scale))
    }

    function placement(output: string, widget: string): var {
        const fallback = defaults[widget]
        const saved = file.value[output]?.[widget]
        if (!saved) return fallback
        return {
            column: saved.column,
            row: saved.row,
            scale: clampScale(saved.scale ?? fallback.scale),
            anchor: saved.anchor ?? fallback.anchor,
        }
    }

    function adjust(output: string, widget: string, change: var): void {
        const layouts = Object.assign({}, file.value)
        layouts[output] = Object.assign({}, layouts[output] ?? {})
        layouts[output][widget] = Object.assign({}, placement(output, widget), change)
        file.save(layouts)
    }

    JsonFile {
        id: file

        path: Paths.state + "/desktop-layout.json"
        fallback: ({})
    }
}
