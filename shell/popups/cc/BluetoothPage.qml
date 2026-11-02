import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.components

// Bluetooth devices: connected first, then paired, then whatever is in range
// and has bothered to say its name.
ColumnLayout {
    id: root

    signal back
    // Whether the page is the one on screen.
    property bool active: false

    readonly property var adapter: BluetoothState.adapter

    readonly property var items: BluetoothState.devices
        .filter(d => BluetoothState.name(d) !== "" || d.paired || d.connected)
        .slice()
        .sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired))

    spacing: 10

    // Discovery costs power and fills the air with inquiries; it runs while the
    // page is up.
    onActiveChanged: {
        if (!adapter) return
        if (active && adapter.enabled) adapter.discovering = true
        else if (!active && adapter.discovering) adapter.discovering = false
    }

    function activate(device: var): void {
        if (device.connected) device.disconnect()
        else {
            if (!device.paired) device.pair()
            device.connect()
        }
    }

    PageHeader {
        title: I18n.tr("Bluetooth")
        onBack: root.back()

        Icon {
            visible: root.adapter?.discovering ?? false
            name: "view-refresh-symbolic"
            dim: true

            Tip {
                text: I18n.tr("Scanning")
            }
        }

        Switch {
            visible: root.adapter !== null
            checked: BluetoothState.powered
            onToggled: on => {
                root.adapter.enabled = on
                if (on && root.active) root.adapter.discovering = true
            }
        }
    }

    Txt {
        visible: root.adapter === null
        text: I18n.tr("No Bluetooth adapter")
        dim: true
    }

    Txt {
        visible: root.adapter !== null && (!BluetoothState.powered || root.items.length === 0)
        Layout.alignment: Qt.AlignHCenter
        Layout.margins: 16
        text: BluetoothState.powered ? I18n.tr("Searching for devices…") : I18n.tr("Turn on Bluetooth to see devices")
        dim: true
    }

    Scroller {
        visible: BluetoothState.powered && root.items.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 360)
        spacing: 2

        Repeater {
            model: root.items

            DeviceRow {
                required property var modelData

                width: parent.width
                icon: Icons.first([modelData.icon + "-symbolic", modelData.icon, "bluetooth-symbolic"])
                title: BluetoothState.name(modelData) || modelData.address
                subtitle: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
                          ? I18n.tr("Connecting…")
                          : modelData.batteryAvailable ? `${Math.round(modelData.battery * 100)}%` : ""
                current: modelData.connected
                onClicked: root.activate(modelData)
            }
        }
    }
}
