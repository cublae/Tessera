import QtQuick
import qs.services

// A one-line entry: search box, network name, password.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool peek: false
    readonly property alias input: input

    signal accepted
    // Keys the entry itself does not use: arrows for a list under it, say.
    // Accept the event to keep it; anything left goes on to the parent.
    signal keyPressed(var event)

    function focusInput(): void {
        input.forceActiveFocus()
    }

    implicitWidth: 240
    implicitHeight: 44
    radius: Math.min(height / 2, Theme.radiusLg)
    color: Theme.fieldBg
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.accent

    Icon {
        id: leading

        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        color: Theme.fg
        dim: true
    }

    TextInput {
        id: input

        anchors.left: leading.visible ? leading.right : parent.left
        anchors.leftMargin: leading.visible ? 12 : 16
        anchors.right: eye.visible ? eye.left : parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        selectionColor: Theme.alpha(Theme.accentBg, 0.5)
        selectedTextColor: Theme.fg
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        clip: true
        echoMode: root.password && !root.peek ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()
        Keys.onPressed: event => root.keyPressed(event)

        Txt {
            anchors.fill: parent
            visible: input.text === ""
            text: root.placeholder
            color: Theme.fg
            dim: true
        }
    }

    Icon {
        id: eye

        visible: root.password
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.peek ? "view-conceal-symbolic" : "view-reveal-symbolic"
        color: Theme.fg
        dim: true

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.peek = !root.peek
        }
    }
}
