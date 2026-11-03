import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

import "../lib/strftime.js" as Strftime

// A month grid, with a stepper and a way back to today.
ColumnLayout {
    id: root

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property date today: new Date()

    // Weekday the grid starts on, 1 Monday .. 7 Sunday. The C library knows
    // this per locale, but Qt's answer disagrees with it often enough that it
    // is a setting rather than a guess.
    readonly property int start: Config.c.calendar.firstDay === "sunday" ? 7 : 1

    function home(): void {
        today = new Date()
        viewYear = today.getFullYear()
        viewMonth = today.getMonth()
    }

    function step(months: int): void {
        const next = new Date(viewYear, viewMonth + months, 1, 12)
        viewYear = next.getFullYear()
        viewMonth = next.getMonth()
    }

    function isWeekend(qtDay: int): bool {
        return qtDay === 6 || qtDay === 7
    }

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4

        IconButton {
            icon: "pan-start-symbolic"
            tooltip: I18n.tr("Previous month")
            minHeight: 32
            onClicked: root.step(-1)
        }

        Button {
            Layout.fillWidth: true
            minHeight: 30
            tooltip: I18n.tr("Back to today")
            onClicked: root.home()

            Txt {
                // `%OB`: the month as it stands alone, "ноябрь 2026" rather than
                // the "ноября" it takes inside a date.
                text: Strftime.format("%OB %Y", new Date(root.viewYear, root.viewMonth, 1, 12), Qt.locale())
                font.weight: Font.Bold
                em: 1.05
            }
        }

        IconButton {
            icon: "pan-end-symbolic"
            tooltip: I18n.tr("Next month")
            minHeight: 32
            onClicked: root.step(1)
        }
    }

    GridLayout {
        columns: 7
        Layout.alignment: Qt.AlignHCenter
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 7

            Txt {
                required property int index
                readonly property int day: (root.start - 1 + index) % 7 + 1

                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName(day % 7, 1).slice(0, 1).toUpperCase()
                em: 0.85
                font.weight: Font.Medium
                color: root.isWeekend(day) ? Theme.destructive : Theme.fg
                opacity: root.isWeekend(day) ? 1 : Theme.dimOpacity
                bottomPadding: 4
            }
        }

        Repeater {
            model: 42

            Rectangle {
                id: cell

                required property int index
                readonly property date first: new Date(root.viewYear, root.viewMonth, 1, 12)
                readonly property int lead: ((first.getDay() || 7) - root.start + 7) % 7
                readonly property date date: new Date(root.viewYear, root.viewMonth, 1 - lead + index, 12)
                readonly property bool other: date.getMonth() !== root.viewMonth
                readonly property bool isToday: date.toDateString() === root.today.toDateString()

                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: isToday ? Theme.accentBg : "transparent"
                opacity: other ? (isToday ? 0.5 : 0.35) : 1

                Txt {
                    anchors.centerIn: parent
                    text: cell.date.getDate()
                    em: 0.95
                    font.weight: cell.isToday ? Font.Medium : Font.Normal
                    color: cell.isToday ? Theme.accentFg : root.isWeekend(cell.date.getDay() || 7) ? Theme.destructive : Theme.fg
                }
            }
        }
    }
}
