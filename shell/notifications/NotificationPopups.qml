import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.services
import qs.components

// Notifications as they arrive, stacked in a corner of one output.
//
// Left to itself the stack follows the bar, because that is where the user is
// already looking: a bar along the bottom raises its popups from the bottom. A
// vertical bar gives no vertical edge to follow, so the popups stay at the top
// and take the side away from it.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string corner: {
        const configured = Config.c.notifications.position
        if (configured !== "auto") return configured
        switch (Config.c.bar.position) {
        case "bottom": return "bottom-right"
        case "right": return "top-left"
        default: return "top-right"
        }
    }
    readonly property bool fromBottom: corner.startsWith("bottom")

    property var cards: []

    screen: modelData
    visible: cards.length > 0
    color: "transparent"
    implicitWidth: 380
    implicitHeight: stack.implicitHeight + 16

    WlrLayershell.namespace: "tessera-notifications"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    anchors {
        top: !root.fromBottom
        bottom: root.fromBottom
        left: root.corner.endsWith("left")
        right: root.corner.endsWith("right")
    }

    function remove(n: var): void {
        cards = cards.filter(c => c !== n)
    }

    Connections {
        target: Notifs

        function onArrived(n) {
            const cfg = Config.c.notifications
            if (Notifs.dnd) return
            // The oldest makes room; it is still in the centre.
            const kept = root.cards.filter(c => c !== n)
            while (kept.length >= Math.max(1, cfg.maxPopups)) kept.shift()
            root.cards = kept.concat([n])
        }
    }

    ColumnLayout {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        y: root.fromBottom ? parent.height - height - 8 : 8
        spacing: 8

        Repeater {
            model: root.cards

            NotificationCard {
                id: card

                required property var modelData

                Layout.fillWidth: true
                notification: modelData
                compact: true
                onDismissed: root.remove(modelData)

                // Critical notifications wait for the user.
                Timer {
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    interval: Math.max(1, Config.c.notifications.timeout) * 1000
                    onTriggered: root.remove(card.modelData)
                }

                Connections {
                    target: card.modelData
                    function onClosed() {
                        root.remove(card.modelData)
                    }
                }

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration
                    }
                }
            }
        }
    }
}
