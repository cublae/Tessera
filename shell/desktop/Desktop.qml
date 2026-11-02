import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.services
import qs.components

import "../lib/strftime.js" as Strftime

// Widgets on the desktop: a large clock, the date, and what is playing.
//
// They sit above the wallpaper and below every window, and are shown only while
// the output's active workspace holds no windows -- a clock behind a
// full-screen editor is a clock nobody can see.
//
// Arranging them is a mode: the layer moves above the windows and takes the
// keyboard, a grid appears, and each widget can be dragged to a grid point,
// scaled with the wheel and hung left, centred or right of its point with a
// right click. Escape or Enter leaves the mode.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string output: modelData.name
    readonly property var cfg: Config.c.desktop
    readonly property bool editing: DesktopLayout.editing

    readonly property bool bare: {
        if (editing) return true
        const active = Niri.workspaces.find(w => w.output === output && w.is_active)
        if (!active) return false
        return !Niri.windows.some(w => w.workspace_id === active.id)
    }

    readonly property var players: Mpris.players.values
    readonly property var player: players[0] ?? null
    readonly property string playing: {
        if (!player || !player.isPlaying) return ""
        const title = (player.trackTitle ?? "").trim()
        if (!title) return ""
        const artist = (player.trackArtist ?? "").trim()
        return artist ? `${artist} — ${title}` : title
    }

    screen: modelData
    color: "transparent"
    // Clicks go through to the desktop beneath unless the layout is being edited.
    mask: editing ? null : empty

    Region {
        id: empty
    }

    WlrLayershell.namespace: "tessera-desktop"
    WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Background
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onEditingChanged: if (editing) keys.forceActiveFocus()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    Item {
        id: canvas

        anchors.fill: parent
        opacity: root.bare ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.duration
            }
        }

        Item {
            id: keys

            focus: true
            Keys.onPressed: event => {
                if (!root.editing) return
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    DesktopLayout.editing = false
                    event.accepted = true
                }
            }
        }

        // The grid, while arranging.
        Canvas {
            id: guides

            anchors.fill: parent
            visible: root.editing
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)
                context.strokeStyle = "rgba(255, 255, 255, 0.16)"
                context.lineWidth = 1
                context.beginPath()
                for (let column = 1; column < DesktopLayout.columns; column++) {
                    const x = Math.round(column / DesktopLayout.columns * width) + 0.5
                    context.moveTo(x, 0)
                    context.lineTo(x, height)
                }
                for (let row = 1; row < DesktopLayout.rows; row++) {
                    const y = Math.round(row / DesktopLayout.rows * height) + 0.5
                    context.moveTo(0, y)
                    context.lineTo(width, y)
                }
                context.stroke()
            }
        }

        Rectangle {
            visible: root.editing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            width: hint.implicitWidth + 24
            height: hint.implicitHeight + 12
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.5)

            Txt {
                id: hint

                anchors.centerIn: parent
                color: "white"
                text: I18n.tr("Drag to move · Scroll to resize · Right-click to align · Esc when done")
            }
        }

        Piece {
            widget: "clock"
            label: I18n.tr("Clock")
            shown: true

            DesktopText {
                text: Strftime.format(root.cfg.clockFormat, clock.date, Qt.locale())
                em: 5
                font.weight: Font.ExtraLight
                font.features: { "tnum": 1 }
            }
        }

        Piece {
            widget: "date"
            label: I18n.tr("Date")
            shown: root.cfg.showDate

            DesktopText {
                text: Strftime.format(root.cfg.dateFormat, clock.date, Qt.locale())
                em: 1.3
                font.weight: Font.Medium
                opacity: 0.9
            }
        }

        Piece {
            widget: "media"
            label: I18n.tr("Now playing")
            shown: root.cfg.showMedia && root.playing !== ""

            RowLayout {
                spacing: 8
                opacity: 0.85

                Icon {
                    name: "media-playback-start-symbolic"
                    color: "white"
                }

                DesktopText {
                    text: root.playing
                    em: 0.95
                }
            }
        }
    }

    component DesktopText: Txt {
        color: "white"
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
        elide: Text.ElideNone
    }

    // One widget, at its grid point.
    component Piece: Rectangle {
        id: piece

        required property string widget
        required property string label
        property bool shown: true
        default property alias body: holder.data

        readonly property var at: DesktopLayout.placement(root.output, widget)
        property real dragX: 0
        property real dragY: 0
        property bool dragging: false

        readonly property real pointX: at.column / DesktopLayout.columns * canvas.width
        readonly property real pointY: at.row / DesktopLayout.rows * canvas.height
        readonly property real hang: at.anchor === "start" ? 0 : at.anchor === "end" ? width : width / 2

        visible: shown || root.editing
        width: (shown ? holder.childrenRect.width * at.scale : placeholder.implicitWidth) + 12
        height: (shown ? holder.childrenRect.height * at.scale : placeholder.implicitHeight) + 8
        x: pointX - hang + dragX
        y: pointY - height / 2 + dragY
        radius: Theme.radiusMd
        color: !root.editing ? "transparent" : dragging ? Qt.rgba(0, 0, 0, 0.6) : area.containsMouse ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.35)
        border.width: root.editing ? 1 : 0
        border.color: dragging || area.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.5)

        Item {
            id: holder

            visible: piece.shown
            x: 6
            y: 4
            width: childrenRect.width
            height: childrenRect.height
            scale: piece.at.scale
            transformOrigin: Item.TopLeft
        }

        Txt {
            id: placeholder

            visible: !piece.shown
            anchors.centerIn: parent
            text: piece.label
            color: "white"
            dim: true
        }

        MouseArea {
            id: area

            property point origin

            anchors.fill: parent
            enabled: root.editing
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: piece.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: mouse => {
                if (mouse.button !== Qt.LeftButton) return
                origin = mapToItem(canvas, mouse.x, mouse.y)
                piece.dragging = true
            }
            onPositionChanged: mouse => {
                if (!piece.dragging) return
                const now = mapToItem(canvas, mouse.x, mouse.y)
                piece.dragX = now.x - origin.x
                piece.dragY = now.y - origin.y
            }
            onReleased: mouse => {
                if (!piece.dragging) return
                piece.dragging = false
                const x = piece.pointX + piece.dragX
                const y = piece.pointY + piece.dragY
                piece.dragX = 0
                piece.dragY = 0
                DesktopLayout.adjust(root.output, piece.widget, {
                    column: Math.max(0, Math.min(DesktopLayout.columns, Math.round(x / canvas.width * DesktopLayout.columns))),
                    row: Math.max(0, Math.min(DesktopLayout.rows, Math.round(y / canvas.height * DesktopLayout.rows))),
                })
            }
            onClicked: mouse => {
                if (mouse.button !== Qt.RightButton) return
                const order = ["center", "start", "end"]
                DesktopLayout.adjust(root.output, piece.widget, { anchor: order[(order.indexOf(piece.at.anchor) + 1) % order.length] })
            }
            onWheel: wheel => {
                DesktopLayout.adjust(root.output, piece.widget, {
                    scale: DesktopLayout.clampScale(piece.at.scale + Math.sign(wheel.angleDelta.y) * 0.1),
                })
            }
        }
    }
}
