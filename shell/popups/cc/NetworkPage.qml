import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Wi-Fi: networks in range, joining, leaving, forgetting, and a way to dial a
// network that is never advertised.
ColumnLayout {
    id: root

    signal back
    // Whether the page is the one on screen.
    property bool active: false

    // `{ kind: "password", network }`, `{ kind: "hidden" }` or null.
    property var prompt: null

    spacing: 10

    readonly property var wifi: Network.wifi

    // Several access points share an SSID on any network bigger than a flat;
    // the list shows each name once, at its strongest.
    readonly property var items: {
        if (!wifi) return []
        const strongest = new Map()
        for (const n of wifi.networks.values) {
            if (!n.name) continue
            const seen = strongest.get(n.name)
            if (!seen || n.signalStrength > seen.signalStrength) strongest.set(n.name, n)
        }
        return Array.from(strongest.values())
            .sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength)
    }

    function dismiss(): void {
        prompt = null
        password.text = ""
        ssid.text = ""
    }

    function submit(): void {
        if (!prompt) return
        if (prompt.kind === "password") {
            prompt.network.connectWithPsk(password.text)
        } else {
            const name = ssid.text.trim()
            if (!name) return
            Network.connectHidden(name, password.text)
        }
        dismiss()
    }

    function activate(network: var): void {
        if (network.connected) network.disconnect()
        else if (Network.secured(network) && !network.known) {
            prompt = { kind: "password", network }
            password.focusInput()
        } else network.connect()
    }

    // Scanning costs radio time; it runs while the page is up.
    onActiveChanged: Network.setScanning(active)
    Component.onDestruction: Network.setScanning(false)

    Keys.onEscapePressed: event => {
        if (prompt) {
            dismiss()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    PageHeader {
        title: I18n.tr("Wi-Fi")
        onBack: root.back()

        IconButton {
            visible: root.wifi !== null
            icon: Icons.add()
            tooltip: I18n.tr("Join a hidden network")
            onClicked: {
                root.prompt = { kind: "hidden" }
                ssid.focusInput()
            }
        }

        Switch {
            visible: root.wifi !== null
            checked: Network.wifiEnabled
            onToggled: on => Network.setWifiEnabled(on)
        }
    }

    Txt {
        visible: root.wifi === null
        text: I18n.tr("No Wi-Fi device")
        dim: true
    }

    ColumnLayout {
        visible: root.prompt !== null
        Layout.fillWidth: true
        spacing: 6

        Field {
            id: ssid

            visible: root.prompt?.kind === "hidden"
            Layout.fillWidth: true
            placeholder: I18n.tr("Network name")
            onAccepted: password.focusInput()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Field {
                id: password

                Layout.fillWidth: true
                password: true
                placeholder: root.prompt?.kind === "password" ? root.prompt.network.name : I18n.tr("Password")
                onAccepted: root.submit()
            }

            IconButton {
                icon: "object-select-symbolic"
                tooltip: I18n.tr("Connect")
                onClicked: root.submit()
            }

            IconButton {
                icon: "window-close-symbolic"
                tooltip: I18n.tr("Cancel")
                onClicked: root.dismiss()
            }
        }
    }

    Txt {
        visible: root.wifi !== null && (!Network.wifiEnabled || root.items.length === 0)
        Layout.alignment: Qt.AlignHCenter
        Layout.margins: 16
        text: Network.wifiEnabled ? I18n.tr("Looking for networks…") : I18n.tr("Turn on Wi-Fi to see networks")
        dim: true
    }

    Scroller {
        visible: Network.wifiEnabled && root.items.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 360)
        spacing: 2

        Repeater {
            model: root.items

            RowLayout {
                id: entry

                required property var modelData

                width: parent.width
                spacing: 2

                DeviceRow {
                    icon: Network.strengthIcon(entry.modelData.signalStrength)
                    title: entry.modelData.name
                    subtitle: entry.modelData.stateChanging ? I18n.tr("Connecting…") : ""
                    current: entry.modelData.connected
                    locked: Network.secured(entry.modelData)
                    onClicked: root.activate(entry.modelData)
                }

                IconButton {
                    visible: entry.modelData.known
                    icon: "user-trash-symbolic"
                    iconColor: Theme.destructive
                    hoverColor: Theme.alpha(Theme.destructive, 0.18)
                    opacity: hovered ? 1 : 0.6
                    tooltip: I18n.tr("Forget this network")
                    onClicked: entry.modelData.forget()
                }
            }
        }
    }
}
