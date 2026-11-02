import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Clipboard history: pick an entry to put it back on the clipboard.
PopupLayer {
    id: root

    name: "clipboard"
    align: "center"
    keyboard: true

    // Images larger than this are listed but not decoded for a thumbnail:
    // a screenshot of a 4K screen is tens of megabytes to read for 64 pixels.
    readonly property real previewLimit: 8 * 1024 * 1024

    readonly property var shownEntries: {
        const term = field.text.trim().toLowerCase()
        const all = Clipboard.entries
        return term ? all.filter(e => e.preview.toLowerCase().indexOf(term) !== -1)
                    : all.slice(0, Math.max(1, Config.c.clipboard.maxVisible))
    }

    onShownChanged: {
        if (shown) {
            field.text = ""
            Clipboard.reload()
            list.currentIndex = 0
        }
    }
    onOpened: field.focusInput()

    function paste(entry: var): void {
        if (!entry) return
        Shell.close()
        Clipboard.copy(entry)
    }

    ColumnLayout {
        width: 520
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Field {
                id: field

                Layout.fillWidth: true
                icon: "edit-paste-symbolic"
                placeholder: I18n.tr("Search clipboard…")
                onTextChanged: list.currentIndex = 0
                onAccepted: root.paste(root.shownEntries[list.currentIndex])
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Down) list.currentIndex = Math.min(root.shownEntries.length - 1, list.currentIndex + 1)
                    else if (event.key === Qt.Key_Up) list.currentIndex = Math.max(0, list.currentIndex - 1)
                    else return
                    event.accepted = true
                }
            }

            IconButton {
                icon: "user-trash-symbolic"
                tooltip: I18n.tr("Clear history")
                minHeight: 36
                onClicked: Clipboard.clear()
            }
        }

        Txt {
            visible: root.shownEntries.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 16
            text: I18n.tr("Clipboard history is empty")
            dim: true
        }

        ListView {
            id: list

            visible: root.shownEntries.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(420, contentHeight)
            clip: true
            spacing: 2
            model: root.shownEntries
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property var image: modelData.image ?? null
                property string thumbnail: ""

                width: list.width
                height: image ? 56 : 38
                radius: Theme.radiusMd
                color: ListView.isCurrentItem ? Theme.alpha(Theme.accent, 0.15) : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.06) : "transparent"

                Component.onCompleted: {
                    if (image && image.bytes <= root.previewLimit)
                        Clipboard.decodeImage(modelData, path => {
                            // The row may have scrolled away and been destroyed meanwhile.
                            if (row) row.thumbnail = path
                        })
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.paste(row.modelData)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    Rectangle {
                        visible: row.image !== null
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 44
                        radius: Theme.radiusSm
                        color: Theme.alpha(Theme.fg, 0.08)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: row.thumbnail ? "file://" + row.thumbnail : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 128
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Txt {
                            Layout.fillWidth: true
                            text: row.image ? `${row.image.type.toUpperCase()} ${row.image.dimensions}` : row.modelData.preview
                            textFormat: Text.PlainText
                        }

                        Txt {
                            visible: row.image !== null
                            text: row.image?.size ?? ""
                            dim: true
                            em: 0.85
                        }
                    }
                }
            }
        }
    }
}
