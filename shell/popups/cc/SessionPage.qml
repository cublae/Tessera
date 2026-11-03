import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Lock, log out, suspend, restart, power off.
ColumnLayout {
    id: root

    signal back

    spacing: 10

    readonly property var actions: [
        { icon: "system-lock-screen-symbolic", label: I18n.tr("Lock"), argv: ["loginctl", "lock-session"] },
        { icon: "system-log-out-symbolic", label: I18n.tr("Log out"), run: () => Compositor.logOut() },
        { icon: "weather-clear-night-symbolic", label: I18n.tr("Suspend"), argv: ["systemctl", "suspend"] },
        { icon: "system-reboot-symbolic", label: I18n.tr("Restart"), argv: ["systemctl", "reboot"] },
        { icon: "system-shutdown-symbolic", label: I18n.tr("Power off"), argv: ["systemctl", "poweroff"] },
    ]

    PageHeader {
        title: I18n.tr("Session")
        onBack: root.back()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: root.actions

            DeviceRow {
                required property var modelData

                icon: modelData.icon
                title: modelData.label
                onClicked: {
                    Shell.close()
                    if (modelData.run) modelData.run()
                    else Quickshell.execDetached(modelData.argv)
                }
            }
        }
    }
}
