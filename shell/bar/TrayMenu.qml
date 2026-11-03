import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// A tray item's menu, drawn by the shell.
//
// The item publishes its menu over DBusMenu; Quickshell reads the tree and
// this lays it out like the shell's other dropdowns, at the bar's edge under
// the icon that opened it. Submenus open in place, with a way back -- a
// cascade of popups is a lot of machinery for menus that are mostly one level.
PanelWindow {
    id: root

    required property var bar
    property var item: null
    // Where along the bar the icon sits, in the bar's own coordinates.
    property real at: 0
    property var stack: []

    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : item?.menu ?? null

    function open(trayItem: var, along: real): void {
        item = trayItem
        at = along
        stack = []
        visible = true
        focusTimer.restart()
    }

    function close(): void {
        visible = false
        item = null
        stack = []
    }

    // GTK menus mark the mnemonic with an underscore; a doubled one is literal.
    function label(text: string): string {
        return (text ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }

    visible: false
    screen: bar.screen
    color: "transparent"

    WlrLayershell.namespace: "tessera-tray-menu"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Closing the bar's dropdown closes this too, and the other way round.
    Connections {
        target: Shell
        function onOpenChanged() {
            if (Shell.open !== "") root.close()
        }
    }

    Timer {
        id: focusTimer

        interval: 10
        onTriggered: scope.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    QsMenuOpener {
        id: opener

        menu: root.current
    }

    Rectangle {
        id: panel

        readonly property string position: root.bar.position
        readonly property bool vertical: root.bar.vertical

        width: Math.max(180, list.implicitWidth + 12)
        height: list.implicitHeight + 12
        radius: Theme.radiusMd
        color: Theme.popoverBg

        x: {
            if (position === "left") return 4
            if (position === "right") return root.width - width - 4
            return Math.max(4, Math.min(root.width - width - 4, root.at - width / 2))
        }
        y: {
            if (position === "top") return 4
            if (position === "bottom") return root.height - height - 4
            return Math.max(4, Math.min(root.height - height - 4, root.at - height / 2))
        }

        MouseArea {
            anchors.fill: parent
        }

        FocusScope {
            id: scope

            anchors.fill: parent
            Keys.onEscapePressed: {
                if (root.stack.length > 0) root.stack = root.stack.slice(0, -1)
                else root.close()
            }
        }

        ColumnLayout {
            id: list

            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            MenuRow {
                visible: root.stack.length > 0
                text: I18n.tr("Back")
                icon: "go-previous-symbolic"
                onActivated: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children.values

                Loader {
                    required property var modelData

                    Layout.fillWidth: true
                    sourceComponent: modelData.isSeparator ? separator : row

                    Component {
                        id: separator

                        Rectangle {
                            implicitHeight: 9
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: Theme.borders
                            }
                        }
                    }

                    Component {
                        id: row

                        MenuRow {
                            entry: modelData
                            text: root.label(modelData.text)
                            icon: modelData.icon
                            enabled: modelData.enabled
                            onActivated: {
                                if (modelData.hasChildren) {
                                    root.stack = root.stack.concat([modelData])
                                } else {
                                    modelData.triggered()
                                    root.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Button {
        id: menuRow

        property var entry: null
        property string text
        property string icon

        signal activated

        Layout.fillWidth: true
        implicitWidth: rowLayout.implicitWidth + 20
        implicitHeight: 30
        radius: Theme.radiusSm
        onClicked: activated()

        RowLayout {
            id: rowLayout

            spacing: 8
            width: menuRow.width - 20

            // A checkbox or radio entry shows its state in place of an icon.
            Icon {
                visible: menuRow.entry !== null && menuRow.entry.buttonType !== 0
                name: menuRow.entry?.checkState === Qt.Checked
                      ? (menuRow.entry?.buttonType === 2 ? "radio-checked-symbolic" : "object-select-symbolic")
                      : ""
                size: 14
            }

            Icon {
                visible: menuRow.icon !== "" && (menuRow.entry === null || menuRow.entry.buttonType === 0)
                name: menuRow.icon.startsWith("image:") || menuRow.icon.startsWith("/") ? "" : menuRow.icon
                source: menuRow.icon.startsWith("image:") ? menuRow.icon : menuRow.icon.startsWith("/") ? "file://" + menuRow.icon : ""
                size: 16
            }

            Txt {
                Layout.fillWidth: true
                text: menuRow.text
                color: Theme.fg
            }

            Icon {
                visible: menuRow.entry?.hasChildren ?? false
                name: "go-next-symbolic"
                size: 14
                dim: true
            }
        }
    }
}
