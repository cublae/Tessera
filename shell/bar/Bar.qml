import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components
import "modules"

// The bar on one output.
//
// The mental model is a main axis and a cross axis. The bar runs along its main
// axis -- horizontal for top and bottom, vertical for left and right -- and is
// anchored to the screen edge on the cross one. Modules ask the bar which way
// it runs instead of each deriving it from the position.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string output: modelData.name
    readonly property string position: Config.c.bar.position
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real size: Config.c.bar.size

    screen: modelData
    color: "transparent"
    implicitHeight: vertical ? 0 : size
    implicitWidth: vertical ? size : 0

    WlrLayershell.namespace: "tessera-bar"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Auto

    anchors {
        top: position !== "bottom"
        bottom: position !== "top"
        left: position !== "right"
        right: position !== "left"
    }

    // Sections left out of an output's own layout fall back to `bar.modules`.
    readonly property var layout: {
        const modules = Config.c.bar.modules
        const override = Config.c.bar.outputs?.[output]
        if (!override) return modules
        return {
            start: override.start ?? modules.start,
            center: override.center ?? modules.center,
            end: override.end ?? modules.end,
        }
    }

    // A tray item's menu, under the icon that asked for it.
    function openMenu(item: var, button: Item): void {
        Shell.close()
        const point = button.mapToItem(root.contentItem, button.width / 2, button.height / 2)
        menu.open(item, vertical ? point.y : point.x)
    }

    TrayMenu {
        id: menu

        bar: root
    }

    // Open a dropdown from this bar, on this bar's screen.
    function toggle(name: string): void {
        Shell.toggle(name, root.screen)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelBg

        // Placed by hand rather than anchored. A section holding a spacer
        // reaches to the centre one, so the spacer has slack to take.
        Section {
            id: startSection

            ids: root.layout.start
            x: root.vertical ? (parent.width - width) / 2 : Theme.spacing
            y: root.vertical ? Theme.spacing : (parent.height - height) / 2
            width: stretch && !root.vertical ? centerSection.x - Theme.spacing * 2 : implicitWidth
            height: stretch && root.vertical ? centerSection.y - Theme.spacing * 2 : implicitHeight
        }

        Section {
            id: centerSection

            ids: root.layout.center
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
        }

        Section {
            id: endSection

            ids: root.layout.end
            readonly property real from: root.vertical ? centerSection.y + centerSection.height + Theme.spacing : centerSection.x + centerSection.width + Theme.spacing
            width: stretch && !root.vertical ? parent.width - Theme.spacing - from : implicitWidth
            height: stretch && root.vertical ? parent.height - Theme.spacing - from : implicitHeight
            x: root.vertical ? (parent.width - width) / 2 : parent.width - width - Theme.spacing
            y: root.vertical ? parent.height - height - Theme.spacing : (parent.height - height) / 2
        }
    }

    component Section: GridLayout {
        property var ids: []
        readonly property bool stretch: (ids ?? []).indexOf("spacer") !== -1

        columns: root.vertical ? 1 : -1
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: parent.ids

            Loader {
                required property string modelData

                Layout.alignment: Qt.AlignCenter
                // A spacer is the one module that takes the slack.
                Layout.fillWidth: modelData === "spacer" && !root.vertical
                Layout.fillHeight: modelData === "spacer" && root.vertical
                // Modules say whether they have anything to show through `shown`;
                // a hidden one must take no room and no spacing.
                visible: item ? (item.shown ?? true) : false
                sourceComponent: root.modules[modelData] ?? null

                Component.onCompleted: {
                    if (!(modelData in root.modules)) console.error(`tessera: unknown bar module "${modelData}", skipping`)
                }
            }
        }
    }

    // Every id accepted in `root.modules.*`. Each needs a line in the Home
    // Manager module's `barModule` enum too; nothing but review keeps the two
    // lists in step.
    readonly property var modules: ({
        "workspaces": workspaces,
        "focused-window": focusedWindow,
        "clock": clock,
        "keyboard-layout": keyboardLayout,
        "system-indicators": systemIndicators,
        "tray": tray,
        "notifications": notifications,
        "launcher": launcher,
        "clipboard": clipboard,
        "control-center": controlCenter,
        "media": media,
        "recording": recording,
        "screencast": screencast,
        "privacy": privacy,
        "resources": resources,
        "weather": weather,
        "spacer": spacer,
    })

    Component { id: workspaces; Workspaces { bar: root } }
    Component { id: focusedWindow; FocusedWindow { bar: root } }
    Component { id: clock; Clock { bar: root } }
    Component { id: keyboardLayout; KeyboardLayout { bar: root } }
    Component { id: systemIndicators; SystemIndicators { bar: root } }
    Component { id: tray; Tray { bar: root } }
    Component { id: notifications; NotificationsButton { bar: root } }
    Component { id: launcher; LauncherButton { bar: root } }
    Component { id: clipboard; ClipboardButton { bar: root } }
    Component { id: controlCenter; ControlCenterButton { bar: root } }
    Component { id: media; Media { bar: root } }
    Component { id: recording; Recording { bar: root } }
    Component { id: screencast; Screencast { bar: root } }
    Component { id: privacy; PrivacyIndicator { bar: root } }
    Component { id: resources; ResourcesReadout { bar: root } }
    Component { id: weather; WeatherButton { bar: root } }
    Component { id: spacer; Item { implicitWidth: 0; implicitHeight: 0 } }
}
