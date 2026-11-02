import QtQuick
import qs.services

// A flat button holding one icon.
Button {
    id: root

    property string icon: ""
    property int iconSize: 16
    property color iconColor: Theme.fg

    padding: 4
    minHeight: 30

    Icon {
        name: root.icon
        size: root.iconSize
        color: root.iconColor
    }
}
