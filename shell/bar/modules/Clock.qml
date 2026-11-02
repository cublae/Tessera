import QtQuick
import Quickshell
import qs.services
import qs.components

import "../../lib/strftime.js" as Strftime

// The time; click for the calendar.
Button {
    id: root

    property var bar

    readonly property var cfg: Config.c.clock

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    vertical: bar.vertical
    tooltip: Strftime.format(cfg.tooltipFormat, clock.date, Qt.locale())
    onClicked: bar.toggle("calendar")

    Txt {
        text: Strftime.format(root.bar.vertical ? root.cfg.verticalFormat : root.cfg.format, clock.date, Qt.locale())
        horizontalAlignment: Text.AlignHCenter
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
