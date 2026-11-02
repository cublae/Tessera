import QtQuick
import qs.services
import qs.components

// The bell, with a dot while anything is unread; click for the centre.
Button {
    id: root

    property var bar

    readonly property bool shown: Config.c.modules.notifications

    tooltip: Notifs.count > 0
             ? `${Notifs.count} ${I18n.plural(Notifs.count, [I18n.tr("notification"), I18n.tr("notifications"), I18n.tr("notifications_many")])}`
             : I18n.tr("Notifications")
    onClicked: bar.toggle("notification-center")

    Icon {
        name: Icons.bell(Notifs.dnd)

        Rectangle {
            visible: Notifs.count > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -1
            width: 7
            height: 7
            radius: 3.5
            color: Theme.accent
        }
    }
}
