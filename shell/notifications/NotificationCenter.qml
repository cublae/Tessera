import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Everything not yet dismissed, grouped by sender.
//
// A burst from one application -- a chat, a download manager -- collapses to
// its newest card and a count, so it does not push everything else off screen.
PopupLayer {
    id: root

    name: "notification-center"
    align: "end"
    tall: true
    panelWidth: 400

    property var expanded: ({})

    readonly property var groups: {
        const map = new Map()
        for (const n of Notifs.list) {
            const key = n.appName || n.desktopEntry || I18n.tr("Notification")
            if (!map.has(key)) map.set(key, [])
            map.get(key).push(n)
        }
        return Array.from(map, ([name, items]) => ({ name, items }))
    }

    function toggleGroup(name: string): void {
        const next = Object.assign({}, expanded)
        if (next[name]) delete next[name]
        else next[name] = true
        expanded = next
    }

    ColumnLayout {
        width: root.panelWidth - root.padding * 2
        height: root.vertical ? implicitHeight : root.height - root.padding * 2
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Txt {
                Layout.fillWidth: true
                text: I18n.tr("Notifications")
                font.weight: Font.Bold
                em: 1.05
            }

            IconButton {
                icon: Icons.bell(Notifs.dnd)
                active: Notifs.dnd
                tooltip: I18n.tr("Do not disturb")
                onClicked: Notifs.setDnd(!Notifs.dnd)
            }

            IconButton {
                icon: "user-trash-symbolic"
                iconColor: Theme.destructive
                enabled: Notifs.count > 0
                tooltip: I18n.tr("Clear all")
                onClicked: Notifs.dismissAll()
            }
        }

        ColumnLayout {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: !root.vertical
            Layout.topMargin: root.vertical ? 24 : 0
            Layout.bottomMargin: root.vertical ? 24 : 0
            spacing: 8

            Item {
                Layout.fillHeight: true
            }

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: Icons.bell(true)
                size: 32
                dim: true
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.tr("No notifications")
                dim: true
            }

            Item {
                Layout.fillHeight: true
            }
        }

        Scroller {
            visible: Notifs.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: !root.vertical
            Layout.preferredHeight: root.vertical ? Math.min(contentHeight, 600) : -1
            spacing: 8

            Repeater {
                model: root.groups

                ColumnLayout {
                    id: group

                    required property var modelData
                    readonly property bool open: root.expanded[modelData.name] === true
                    readonly property bool several: modelData.items.length > 1

                    width: parent.width
                    spacing: 8

                    RowLayout {
                        visible: group.several
                        Layout.fillWidth: true
                        spacing: 6

                        Txt {
                            Layout.fillWidth: true
                            text: group.modelData.name
                            font.weight: Font.DemiBold
                            em: 0.9
                        }

                        Button {
                            tooltip: group.open ? I18n.tr("Collapse") : `${I18n.tr("Show all")} ${group.modelData.items.length}`
                            onClicked: root.toggleGroup(group.modelData.name)

                            Txt {
                                text: group.modelData.items.length
                            }

                            Icon {
                                name: group.open ? "pan-up-symbolic" : "pan-down-symbolic"
                                size: 12
                            }
                        }

                        IconButton {
                            icon: "user-trash-symbolic"
                            iconSize: 12
                            iconColor: Theme.destructive
                            tooltip: `${I18n.tr("Dismiss all from")} ${group.modelData.name}`
                            onClicked: {
                                for (const n of group.modelData.items.slice()) n.dismiss()
                            }
                        }
                    }

                    Repeater {
                        model: group.open || !group.several ? group.modelData.items : group.modelData.items.slice(0, 1)

                        NotificationCard {
                            required property var modelData

                            Layout.fillWidth: true
                            notification: modelData
                        }
                    }
                }
            }
        }
    }
}
