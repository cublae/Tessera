import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

import "../lib/strftime.js" as Strftime

// Today's date, over the month.
PopupLayer {
    id: root

    name: "calendar"
    align: "center"

    onOpened: calendar.home()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        width: Math.max(300, implicitWidth)
        spacing: 8

        Txt {
            text: Strftime.format(Config.c.clock.tooltipFormat, clock.date, Qt.locale())
            font.weight: Font.Bold
            em: 1.1
            Layout.bottomMargin: 4
        }

        Calendar {
            id: calendar
        }
    }
}
