import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// CPU, memory and temperature, from /proc and hwmon.
GridLayout {
    id: root

    property var bar

    readonly property var cfg: Config.c.resources

    columns: bar.vertical ? 1 : -1
    columnSpacing: 8
    rowSpacing: 4

    Component.onCompleted: Resources.watchers += 1
    Component.onDestruction: Resources.watchers -= 1

    Reading {
        visible: root.cfg.showCpu
        name: "CPU"
        value: `${Math.round(Resources.cpu * 100)}%`
        tooltip: I18n.tr("CPU load")
    }

    Reading {
        visible: root.cfg.showMemory
        name: "RAM"
        value: `${Math.round(Resources.memory * 100)}%`
        tooltip: I18n.tr("Memory in use")
    }

    // Hidden anyway where nothing reports a temperature.
    Reading {
        visible: root.cfg.showTemperature && Resources.temperature >= 0
        name: "TEMP"
        value: `${Resources.temperature}°`
        tooltip: I18n.tr("CPU temperature")
    }

    component Reading: Row {
        property string name
        property string value
        property string tooltip

        spacing: 4

        Txt {
            text: parent.name
            dim: true
            em: 0.85
        }

        Txt {
            text: parent.value
            font.features: { "tnum": 1 }
        }

        Tip {
            text: parent.tooltip
        }
    }
}
