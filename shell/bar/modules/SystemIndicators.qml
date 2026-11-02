import QtQuick
import qs.services
import qs.components

// Network, volume and battery; click for the control center.
Button {
    id: root

    property var bar

    vertical: bar.vertical
    spacing: 4
    tooltip: I18n.tr("Control center")
    onClicked: bar.toggle("control-center")

    Icon {
        visible: Network.wifi !== null || Network.wired !== null
        name: Network.icon

        Tip {
            text: Network.tooltip
        }
    }

    Icon {
        visible: Audio.speaker !== null
        name: Audio.volumeIcon(Audio.speaker?.audio?.volume ?? 0, Audio.speaker?.audio?.muted ?? false)

        Tip {
            text: Audio.speaker?.audio?.muted ? I18n.tr("Muted") : `${Math.round((Audio.speaker?.audio?.volume ?? 0) * 100)}%`
        }
    }

    Icon {
        visible: Battery.available
        name: Battery.iconName

        Tip {
            text: Battery.tooltip()
        }
    }
}
