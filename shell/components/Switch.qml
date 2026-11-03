import QtQuick
import qs.services

// A Material switch: the thumb grows when it is on.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    radius: height / 2
    color: checked ? Theme.accentBg : Theme.fieldBg
    border.width: checked && !activeFocus ? 0 : 2
    border.color: activeFocus ? Theme.accent : Theme.outline
    activeFocusOnTab: true

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Keys.onSpacePressed: toggled(!checked)
    Keys.onReturnPressed: toggled(!checked)

    Rectangle {
        width: root.checked ? 24 : 16
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 8
        color: root.checked ? Theme.accentFg : Theme.outline

        Behavior on x {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easing
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
