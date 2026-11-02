import QtQuick
import qs.services

// An Adwaita switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Theme.accentBg : Theme.alpha(Theme.fg, 0.15)
    border.width: activeFocus ? 2 : 0
    border.color: Theme.accent
    activeFocusOnTab: true

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Keys.onSpacePressed: toggled(!checked)
    Keys.onReturnPressed: toggled(!checked)

    Rectangle {
        width: 20
        height: 20
        radius: 10
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: "white"

        Behavior on x {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
