import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// One row of a device list: a network, a Bluetooth device, an output.
Button {
    id: root

    property string icon: ""
    property string iconSource: ""
    property string title: ""
    property string subtitle: ""
    property bool current: false
    property bool locked: false
    default property alias trailing: extra.data

    Layout.fillWidth: true
    fill: true
    padding: 10
    minHeight: subtitle ? 44 : 36
    color: current ? Theme.alpha(Theme.accent, 0.15) : pressed ? activeColor : hovered ? hoverColor : "transparent"

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Icon {
            name: root.icon
            source: root.iconSource
            color: root.current ? Theme.accent : Theme.fg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                Layout.fillWidth: true
                text: root.title
                color: root.current ? Theme.accent : Theme.fg
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                dim: true
                em: 0.8
            }
        }

        Icon {
            visible: root.locked
            name: "network-wireless-encrypted-symbolic"
            dim: true
        }

        Icon {
            visible: root.current
            name: "object-select-symbolic"
            color: Theme.accent
        }

        RowLayout {
            id: extra
        }
    }
}
