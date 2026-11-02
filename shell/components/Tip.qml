import QtQuick
import Quickshell
import qs.services

// A tooltip for whatever it is placed in.
//
// Layer-shell surfaces get no tooltips from the toolkit, so this is a popup of
// its own, anchored to its parent and opened on the side away from the bar.
Item {
    id: root

    property string text: ""
    property Item target: parent
    // Which side of the target to open on; follows the bar unless told.
    property int edge: {
        switch (Config.c.bar.position) {
        case "top": return Edges.Bottom
        case "left": return Edges.Right
        case "right": return Edges.Left
        default: return Edges.Top
        }
    }

    anchors.fill: parent

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (!hovered) popup.visible = false
        }
    }

    Timer {
        interval: 600
        running: hover.hovered && root.text !== "" && !popup.visible
        onTriggered: popup.visible = true
    }

    onTextChanged: {
        if (text === "") popup.visible = false
    }

    PopupWindow {
        id: popup

        anchor.item: root.target
        anchor.edges: root.edge
        anchor.gravity: root.edge
        anchor.adjustment: PopupAdjustment.All

        implicitWidth: bubble.width + 12
        implicitHeight: bubble.height + 12
        color: "transparent"

        Rectangle {
            id: bubble

            anchors.centerIn: parent
            width: label.implicitWidth + 16
            height: label.implicitHeight + 10
            radius: Math.min(Theme.radiusMd, height / 2)
            color: Theme.popoverBg
            border.color: Theme.borders
            border.width: 1

            Txt {
                id: label

                anchors.centerIn: parent
                text: root.text
                textFormat: Text.StyledText
                elide: Text.ElideNone
                em: 0.92
                color: Theme.named("popover_fg_color")
            }
        }
    }
}
