import QtQuick
import qs.services
import qs.components

// Temperature and sky; click for the forecast. Not built at all until a place
// is configured.
Button {
    id: root

    property var bar

    readonly property bool shown: Weather.configured && Weather.now !== null
    readonly property var now: Weather.now

    function degrees(value: real): string {
        return `${Math.round(value)}°`
    }

    vertical: bar.vertical
    tooltip: {
        if (Weather.error && !now) return `${I18n.tr("Weather unavailable")}: ${Weather.error}`
        if (!now) return ""
        const head = Weather.place?.name ? `${Weather.place.name}\n` : ""
        return `${head}${now.label}, ${I18n.tr("feels like")} ${degrees(now.apparent)}\n${I18n.tr("Humidity")} ${Math.round(now.humidity)}%`
    }
    onClicked: bar.toggle("weather")

    Icon {
        name: root.now?.icon ?? ""
    }

    Txt {
        text: root.now ? root.degrees(root.now.temperature) : ""
    }
}
