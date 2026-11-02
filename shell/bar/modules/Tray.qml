import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// StatusNotifierItems. Click activates, right click opens the item's menu,
// middle click is the secondary action, scrolling is passed through.
//
// An item that is only a menu -- plenty of them are -- opens the menu on a
// plain click too, since activating it would do nothing.
GridLayout {
    id: root

    property var bar

    readonly property var items: SystemTray.items.values
    readonly property bool shown: items.length > 0

    columns: bar.vertical ? 1 : -1
    columnSpacing: 2
    rowSpacing: 2

    Repeater {
        model: root.items

        Button {
            id: button

            required property var modelData

            padding: 4
            minHeight: 24
            radius: Theme.radiusSm
            tooltip: modelData.tooltipTitle || modelData.title || ""

            onClicked: {
                if (modelData.onlyMenu && modelData.hasMenu) root.bar.openMenu(modelData, button)
                else modelData.activate()
            }
            onRightClicked: {
                if (modelData.hasMenu) root.bar.openMenu(modelData, button)
            }
            onMiddleClicked: modelData.secondaryActivate()
            onScrolled: (dx, dy) => {
                if (dy !== 0) modelData.scroll(Math.round(-dy * 120), false)
                if (dx !== 0) modelData.scroll(Math.round(-dx * 120), true)
            }

            Icon {
                source: button.modelData.icon
                size: 16
            }
        }
    }
}
