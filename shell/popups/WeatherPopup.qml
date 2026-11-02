import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

import "../lib/strftime.js" as Strftime

// Now, and the days ahead.
PopupLayer {
    id: root

    name: "weather"
    align: "end"

    readonly property var now: Weather.now

    function degrees(value: real): string {
        return `${Math.round(value)}°`
    }

    function wind(speed: real): string {
        return `${Math.round(speed)} ${Config.c.weather.units === "imperial" ? "mph" : I18n.tr("km/h")}`
    }

    ColumnLayout {
        width: 300
        spacing: 8

        Txt {
            Layout.fillWidth: true
            visible: Boolean(Weather.place?.name)
            text: Weather.place?.name ?? ""
            font.weight: Font.Bold
        }

        RowLayout {
            visible: root.now !== null
            spacing: 12

            Icon {
                name: root.now?.icon ?? ""
                size: 48
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    text: root.now ? root.degrees(root.now.temperature) : ""
                    em: 2
                    font.weight: Font.Light
                }

                Txt {
                    text: root.now?.label ?? ""
                }

                Txt {
                    dim: true
                    em: 0.9
                    text: root.now ? `${I18n.tr("Feels like")} ${root.degrees(root.now.apparent)} · ${Math.round(root.now.humidity)}% · ${root.wind(root.now.wind)}` : ""
                }
            }
        }

        Repeater {
            // Today is the block above.
            model: Weather.forecast.slice(1)

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 10

                Txt {
                    Layout.preferredWidth: 40
                    text: {
                        const [y, m, d] = modelData.date.split("-").map(Number)
                        return Strftime.format("%a", new Date(y, m - 1, d, 12), Qt.locale())
                    }
                }

                Icon {
                    name: modelData.icon
                }

                Txt {
                    Layout.fillWidth: true
                    text: modelData.label
                    dim: true
                }

                Txt {
                    text: root.degrees(modelData.low)
                    dim: true
                }

                Txt {
                    text: root.degrees(modelData.high)
                }
            }
        }

        ColumnLayout {
            visible: root.now === null && Weather.error !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignHCenter
                name: "network-offline-symbolic"
                size: 32
                dim: true
            }

            Txt {
                text: I18n.tr("No weather right now")
                dim: true
            }
        }
    }
}
