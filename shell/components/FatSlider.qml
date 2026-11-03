import QtQuick
import qs.services

// The thick slider of a quick-settings panel, with its icon inside the track.
//
// The value it shows is whatever `value` is bound to, and moving it reports
// through `moved` rather than writing back -- the volume a slider shows has to
// be the endpoint's, not the slider's idea of it, or a key press elsewhere
// would leave the two disagreeing.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property string tooltip: ""
    property real step: 0.05

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 44
    activeFocusOnTab: true

    readonly property real shown: Math.min(1, Math.max(0, value))

    function report(x: real): void {
        moved(Math.min(1, Math.max(0, (x - height / 2) / (width - height))))
    }

    Keys.onLeftPressed: moved(Math.max(0, shown - step))
    Keys.onRightPressed: moved(Math.min(1, shown + step))

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.fieldBg
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent

        Rectangle {
            height: parent.height
            width: parent.height + (parent.width - parent.height) * root.shown
            radius: height / 2
            color: Theme.accentBg
        }
    }

    Icon {
        anchors.left: parent.left
        anchors.leftMargin: (root.height - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 20
        color: Theme.accentFg
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) root.report(mouse.x)
        }
        onWheel: wheel => root.moved(Math.min(1, Math.max(0, root.shown + Math.sign(wheel.angleDelta.y) * root.step)))
    }

    Tip {
        text: root.tooltip
    }
}
