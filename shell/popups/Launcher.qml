import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

import "../lib/calculator.js" as Calculator
import "../lib/units.js" as Units
import "../lib/emoji.js" as Emoji

// Search applications, and a little more.
//
// Typed arithmetic or a unit conversion answers above the apps and Enter copies
// the answer. `>` runs the rest of the line as a command; `:` searches emoji.
// Ctrl+P pins the selected application to the top of the empty list.
PopupLayer {
    id: root

    name: "launcher"
    floating: true
    keyboard: true

    readonly property int pageRows: 7
    property string query: ""
    property var results: []

    onShownChanged: {
        if (shown) {
            field.text = ""
            search("")
        }
    }
    onOpened: field.focusInput()

    function search(text: string): void {
        query = text
        const term = text.trim()

        if (term.startsWith(">")) {
            const line = term.slice(1).trim()
            fill(line ? [{ kind: "command", line }] : [])
            return
        }
        if (term.startsWith(":")) {
            fill(Emoji.search(term.slice(1).trim(), 200).map(emoji => ({ kind: "emoji", emoji })))
            return
        }

        const apps = Apps.search(term).map(app => ({ kind: "app", app }))
        const value = Calculator.calculate(term) ?? Units.convert(term)
        fill(value === null ? apps : [{ kind: "answer", value }].concat(apps))
    }

    function fill(rows: var): void {
        results = rows
        list.currentIndex = rows.length > 0 ? 0 : -1
        list.positionViewAtBeginning()
    }

    function activate(result: var): void {
        if (!result) return
        Shell.close()

        if (result.kind === "app") Apps.launch(result.app)
        else if (result.kind === "command") Quickshell.execDetached(["sh", "-lc", result.line])
        else Clipboard.copyText(result.kind === "emoji" ? result.emoji.char : result.value)
    }

    function move(step: int): void {
        if (results.length === 0) return
        list.currentIndex = Math.min(results.length - 1, Math.max(0, list.currentIndex + step))
    }

    function togglePin(app: var): void {
        Apps.togglePin(app)
        const keep = list.currentIndex
        search(field.text)
        list.currentIndex = Math.min(keep, results.length - 1)
    }

    ColumnLayout {
        width: 440
        spacing: 10

        Field {
            id: field

            Layout.fillWidth: true
            icon: "system-search-symbolic"
            placeholder: I18n.tr("Search applications…")
            onTextChanged: root.search(text)
            onAccepted: root.activate(root.results[list.currentIndex])

            onKeyPressed: event => {
                if (event.key === Qt.Key_Down) root.move(1)
                else if (event.key === Qt.Key_Up) root.move(-1)
                else if (event.key === Qt.Key_PageDown) root.move(root.pageRows)
                else if (event.key === Qt.Key_PageUp) root.move(-root.pageRows)
                else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                    const selected = root.results[list.currentIndex]
                    if (selected?.kind === "app") root.togglePin(selected.app)
                } else return
                event.accepted = true
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 420

            Txt {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: I18n.tr("No matches")
                dim: true
            }

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.results
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                currentIndex: 0

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property var app: modelData.kind === "app" ? modelData.app : null

                    width: list.width
                    height: 52
                    radius: Theme.radiusMd
                    color: current ? Theme.secondaryContainer : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.activate(row.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 12

                        Icon {
                            visible: row.modelData.kind !== "emoji"
                            size: 32
                            name: {
                                switch (row.modelData.kind) {
                                case "app": return row.app.icon
                                case "answer": return "accessories-calculator-symbolic"
                                default: return "utilities-terminal-symbolic"
                                }
                            }
                            fallback: Icons.fallbackApp
                        }

                        Txt {
                            visible: row.modelData.kind === "emoji"
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.emoji?.char ?? ""
                            em: 1.6
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Txt {
                                Layout.fillWidth: true
                                text: {
                                    switch (row.modelData.kind) {
                                    case "app": return row.app.name
                                    case "answer": return "= " + row.modelData.value
                                    case "command": return row.modelData.line
                                    default: return row.modelData.emoji.name
                                    }
                                }
                            }

                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                dim: true
                                em: 0.85
                                text: {
                                    switch (row.modelData.kind) {
                                    case "app": return row.app.comment || row.app.genericName || ""
                                    case "answer": return I18n.tr("Press Enter to copy")
                                    case "command": return I18n.tr("Run command")
                                    default: return row.modelData.emoji.group
                                    }
                                }
                            }
                        }

                        IconButton {
                            visible: row.app !== null && (row.current || mouse.containsMouse || pinned)
                            readonly property bool pinned: row.app ? Apps.isPinned(row.app) : false
                            icon: pinned ? "starred-symbolic" : "non-starred-symbolic"
                            iconColor: pinned ? Theme.accent : Theme.fg
                            tooltip: pinned ? I18n.tr("Unpin") : I18n.tr("Pin to the top")
                            activeFocusOnTab: false
                            onClicked: root.togglePin(row.app)
                        }
                    }
                }
            }
        }
    }
}
