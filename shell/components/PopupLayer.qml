import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// A dropdown: a panel coming out of the bar, over a transparent layer that
// covers the rest of the screen so a click anywhere else closes it.
//
// The layer respects the bar's exclusive zone, so its edge *is* the bar's edge:
// the panel is a sheet floating a `gap` off it and off the screen's edges.
// `align` positions it along the bar -- a clock in the centre section wants
// its calendar centred. `tall` stretches it across the screen, for the
// notification list; `floating` centres it on screen with every corner round,
// for the launcher.
PanelWindow {
    id: root

    required property string name
    property string align: "center"
    property bool tall: false
    property bool floating: false
    property bool keyboard: false
    property real panelWidth: 0
    property real padding: 20
    readonly property real gap: floating ? 0 : 8

    // Called on Escape before the dropdown closes; returning true keeps it
    // open, for a page that wants to step back first.
    property var onEscape: null

    default property alias content: body.data

    readonly property bool shown: Shell.open === name
    readonly property string position: Config.c.bar.position
    readonly property bool vertical: position === "left" || position === "right"

    signal opened

    // Mapped while shown and through the closing animation.
    property bool mapped: false
    property real progress: 0

    visible: mapped
    screen: Shell.screen ?? Quickshell.screens[0]
    color: "transparent"

    WlrLayershell.namespace: "tessera-" + name
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? (keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
    exclusionMode: floating ? ExclusionMode.Ignore : ExclusionMode.Normal

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onShownChanged: {
        if (shown) {
            mapped = true
            progress = 1
            focusTimer.restart()
        } else {
            progress = 0
        }
    }

    Behavior on progress {
        NumberAnimation {
            id: slide

            duration: Theme.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.easing
            onRunningChanged: {
                if (!running && root.progress === 0) root.mapped = false
            }
        }
    }

    onProgressChanged: {
        if (progress === 0 && Theme.duration === 0) mapped = false
    }

    // Focus once the surface is mapped and has the keyboard.
    Timer {
        id: focusTimer

        interval: 10
        onTriggered: {
            scope.forceActiveFocus()
            root.opened()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.close()
    }

    // Clips the slide at the bar's edge, so the panel appears to come out of
    // the bar rather than over it. Wider than the panel on the other sides,
    // which leaves room for the shadow.
    Item {
        id: holder

        readonly property real shadow: 24

        clip: !root.floating
        width: panel.width + (root.vertical ? shadow + root.gap : shadow * 2)
        height: root.tall && !root.vertical ? root.height : panel.height + (root.vertical ? shadow * 2 : shadow + root.gap)

        x: {
            if (root.floating) return (root.width - width) / 2
            if (root.position === "left") return 0
            if (root.position === "right") return root.width - width
            if (root.align === "start") return root.gap - shadow
            if (root.align === "end") return root.width - width + shadow - root.gap
            return (root.width - width) / 2
        }
        y: {
            if (root.floating) return (root.height - height) / 2
            if (root.tall && !root.vertical) return 0
            if (root.position === "top") return 0
            if (root.position === "bottom") return root.height - height
            if (root.align === "start") return root.gap - shadow
            if (root.align === "end") return root.height - height + shadow - root.gap
            return (root.height - height) / 2
        }

        // Swallow clicks on the panel's own area so they do not close it.
        MouseArea {
            x: panel.x
            y: panel.y
            width: panel.width
            height: panel.height
        }

        RectangularShadow {
            x: panel.x
            y: panel.y + 4
            width: panel.width
            height: panel.height
            opacity: panel.opacity
            scale: panel.scale
            radius: Theme.radiusLg
            blur: root.floating ? 32 : 20
            color: Theme.shadow
        }

        Rectangle {
            id: panel

            readonly property real offset: (1 - root.progress) * ((root.vertical ? width : height) + root.gap)

            width: root.panelWidth > 0 ? root.panelWidth : body.implicitWidth + root.padding * 2
            height: root.tall && !root.vertical ? root.height - root.gap * 2 : body.implicitHeight + root.padding * 2

            x: {
                if (root.floating) return holder.shadow
                if (root.position === "left") return root.gap - offset
                if (root.position === "right") return holder.shadow + offset
                return holder.shadow
            }
            y: {
                if (root.floating) return holder.shadow
                if (root.tall && !root.vertical) return root.gap
                if (root.position === "top") return root.gap - offset
                if (root.position === "bottom") return holder.shadow + offset
                return holder.shadow
            }

            opacity: root.floating ? root.progress : Math.min(1, root.progress * 1.5)
            scale: root.floating ? 0.96 + 0.04 * root.progress : 1

            color: Theme.panelBg
            radius: Theme.radiusLg

            FocusScope {
                id: scope

                anchors.fill: parent
                anchors.margins: root.padding

                Keys.onEscapePressed: {
                    if (root.onEscape && root.onEscape()) return
                    Shell.close()
                }

                Item {
                    id: body

                    anchors.fill: parent
                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                }
            }
        }
    }
}
