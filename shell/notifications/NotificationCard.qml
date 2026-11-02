import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.services
import qs.components

// One notification: who sent it and when, what it says, what can be done.
Rectangle {
    id: root

    required property var notification
    property bool compact: false

    signal dismissed

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property bool low: notification.urgency === NotificationUrgency.Low
    readonly property var actions: notification.actions.filter(a => a.identifier !== "default" && a.text)

    property real now: Date.now()

    // Ages read "5 minutes ago"; half a minute is as fine as that needs.
    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }

    function age(count: int, unit: string): string {
        const forms = I18n.language === "ru"
            ? { minute: ["минуту", "минуты", "минут"], hour: ["час", "часа", "часов"], day: ["день", "дня", "дней"] }
            : { minute: ["minute", "minutes", "minutes"], hour: ["hour", "hours", "hours"], day: ["day", "days", "days"] }
        const word = I18n.plural(count, forms[unit])
        return I18n.language === "ru" ? `${count} ${word} назад` : `${count} ${word} ago`
    }

    readonly property string relative: {
        const delta = Math.max(0, (now - Notifs.time(notification)) / 1000)
        if (delta < 60) return I18n.tr("just now")
        if (delta < 3600) return age(Math.floor(delta / 60), "minute")
        if (delta < 86400) return age(Math.floor(delta / 3600), "hour")
        return age(Math.floor(delta / 86400), "day")
    }

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 24
    radius: Theme.radiusLg
    color: compact ? Theme.panelBg : Theme.cardBg
    border.width: critical ? 2 : compact ? 1 : 0
    border.color: critical ? Theme.destructive : Theme.borders
    opacity: low ? 0.9 : 1

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Txt {
                text: root.notification.appName || I18n.tr("Notification")
                font.weight: Font.DemiBold
                em: 0.85
            }

            Txt {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.relative
                dim: true
                em: 0.85
            }

            IconButton {
                icon: "window-close-symbolic"
                iconSize: 12
                minHeight: 22
                padding: 3
                radius: 11
                tooltip: I18n.tr("Dismiss")
                onClicked: {
                    root.notification.dismiss()
                    root.dismissed()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // The notification's own picture when it has one big enough to be
            // a picture; otherwise the sender's icon.
            Item {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: picture.visible ? Math.min(76, Math.max(54, picture.implicitWidth * 54 / Math.max(1, picture.implicitHeight))) : 32
                Layout.preferredHeight: picture.visible ? 54 : 32

                Image {
                    id: picture

                    anchors.fill: parent
                    visible: status === Image.Ready && implicitWidth >= 54 && implicitHeight >= 54
                    source: root.notification.image
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.height: 108
                    layer.enabled: true
                }

                Icon {
                    visible: !picture.visible
                    anchors.fill: parent
                    size: 32
                    name: picture.status === Image.Ready ? "" : Notifs.appIconOf(root.notification)
                    source: picture.status === Image.Ready ? root.notification.image : ""
                    fallback: "dialog-information-symbolic"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification.summary
                    textFormat: Text.PlainText
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.compact ? 4 : 12
                    dim: true
                }
            }
        }

        RowLayout {
            visible: root.actions.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.actions

                Button {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    minHeight: 30
                    color: hovered ? Theme.alpha(Theme.fg, 0.14) : Theme.alpha(Theme.fg, 0.08)
                    onClicked: modelData.invoke()

                    Txt {
                        text: modelData.text
                    }
                }
            }
        }
    }
}
