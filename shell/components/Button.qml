import QtQuick
import QtQuick.Layouts
import qs.services

// A flat button: the shape every clickable thing in the shell takes.
//
// Transparent at rest, with Material's state layers: a wash of the text colour
// on hover, a stronger one when pressed or `active`. Children are laid out in a row, or a column when
// `vertical` -- which is what a module on a side bar wants.
Rectangle {
    id: root

    property bool active: false
    property bool vertical: false
    property string tooltip: ""
    property real padding: Theme.spacing
    property real spacing: 6
    property real minHeight: 28
    // Stretch the content across the button instead of centring it, for rows
    // whose text should elide at the button's edge.
    property bool fill: false
    property color activeColor: Theme.alpha(Theme.fg, 0.12)
    property color hoverColor: Theme.alpha(Theme.fg, 0.08)
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: area.pressed
    readonly property real contentWidth: layout.implicitWidth + padding * 2

    default property alias content: layout.data

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(real dx, real dy)

    implicitWidth: Math.max(minHeight, contentWidth)
    implicitHeight: Math.max(minHeight, layout.implicitHeight + (vertical ? padding * 2 : 4))
    radius: Math.min(height / 2, Theme.radiusLg)
    opacity: enabled ? 1 : 0.45
    color: pressed || active ? activeColor : hovered ? hoverColor : "transparent"
    border.width: activeFocus ? 2 : 0
    border.color: Theme.accent
    activeFocusOnTab: enabled

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onEnterPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()

    GridLayout {
        id: layout

        anchors.centerIn: root.fill ? undefined : parent
        anchors.fill: root.fill ? parent : undefined
        anchors.leftMargin: root.fill ? root.padding : 0
        anchors.rightMargin: root.fill ? root.padding : 0
        columns: root.vertical ? 1 : -1
        columnSpacing: root.spacing
        rowSpacing: root.spacing
    }

    // Not the MouseArea's `containsMouse`: a `Tip` lies on top of it and takes the
    // hover events, so the area would only learn of the pointer from a press, and
    // never hear that it left -- leaving the button lit after every click.
    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) root.rightClicked()
            else if (mouse.button === Qt.MiddleButton) root.middleClicked()
            else root.clicked()
        }
        onWheel: wheel => {
            // Scroll up reads as a negative delta, the way GTK reports it.
            root.scrolled(-wheel.angleDelta.x / 120, -wheel.angleDelta.y / 120)
        }
    }

    Tip {
        text: root.tooltip
    }
}
