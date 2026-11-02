pragma Singleton

import QtQuick
import Quickshell

// Weather, from Open-Meteo.
//
// Chosen because it needs no API key. Every other free service wants one, which
// would mean either shipping a key in a public repository or making the module
// useless until the user registers for one -- and a weather readout is not
// worth an account.
//
// Conditions come back as WMO codes. They are grouped rather than translated
// one for one: the difference between slight and moderate drizzle is not
// something an icon in a panel can show.
Singleton {
    id: root

    readonly property var cfg: Config.c.weather

    // Where to report from. There is no default and no guess: locating by IP
    // would hand the address to a geolocation service before the user agreed
    // to anything, and the timezone puts you in the wrong half of a continent.
    readonly property bool configured: cfg.latitude !== 0 || cfg.longitude !== 0 || cfg.location.trim() !== ""

    // `{ temperature, apparent, humidity, wind, label, icon }`, or null until
    // the first fetch lands.
    property var now: null
    // Today first: `{ date, high, low, label, icon }`.
    property var forecast: []
    // Why the last fetch failed, or "". Kept rather than only logged: a laptop
    // is offline often enough that "no weather" needs to say which nothing.
    property string error: ""
    // `{ latitude, longitude, name }` once it has been worked out.
    property var place: null

    // Days of forecast to ask for, today included.
    readonly property int days: 4

    function condition(code: int): var {
        if (code === 0) return { label: I18n.tr("Clear_weather"), icons: ["weather-clear-symbolic"] }
        if (code <= 2) return { label: I18n.tr("Partly cloudy"), icons: ["weather-few-clouds-symbolic"] }
        if (code === 3) return { label: I18n.tr("Overcast"), icons: ["weather-overcast-symbolic"] }
        if (code <= 48) return { label: I18n.tr("Fog"), icons: ["weather-fog-symbolic", "weather-overcast-symbolic"] }
        if (code <= 57) return { label: I18n.tr("Drizzle"), icons: ["weather-showers-scattered-symbolic"] }
        if (code <= 67) return { label: I18n.tr("Rain"), icons: ["weather-showers-symbolic"] }
        if (code <= 77) return { label: I18n.tr("Snow"), icons: ["weather-snow-symbolic"] }
        if (code <= 82) return { label: I18n.tr("Rain showers"), icons: ["weather-showers-symbolic"] }
        if (code <= 86) return { label: I18n.tr("Snow showers"), icons: ["weather-snow-symbolic"] }
        return { label: I18n.tr("Thunderstorm"), icons: ["weather-storm-symbolic"] }
    }

    function icon(names: var): string {
        return Icons.first(names.concat(["weather-few-clouds-symbolic"]))
    }

    // Work out where to report from, once per session. Coordinates win over the
    // name when both are given, but the name is still looked up: it is the only
    // source of something to call the place.
    function resolvePlace(callback: var): void {
        if (place) return callback(place)

        const exact = cfg.latitude !== 0 || cfg.longitude !== 0
        const named = cfg.location.trim()
        const fallback = () => {
            if (!exact) return callback(null)
            place = { latitude: cfg.latitude, longitude: cfg.longitude, name: "" }
            callback(place)
        }
        if (!named) return fallback()

        // The geocoder answers in the user's own language when asked; it rejects
        // an empty one.
        const language = (Qt.locale().name || "en").slice(0, 2).toLowerCase()
        const url = "https://geocoding-api.open-meteo.com/v1/search?" + Http.query({ name: named, count: "1", language, format: "json" })
        Http.getJson(url, (error, data) => {
            const hit = data?.results?.[0]
            if (error || !hit) {
                console.error(`tessera: weather: could not look up "${named}": ${error || "no such place"}`)
                return fallback()
            }
            // A bare name is ambiguous often enough to qualify -- there are a
            // dozen Springfields -- but a full address is too much for a panel.
            const name = hit.country ? `${hit.name}, ${hit.country}` : hit.name
            place = exact ? { latitude: cfg.latitude, longitude: cfg.longitude, name }
                          : { latitude: hit.latitude, longitude: hit.longitude, name }
            callback(place)
        })
    }

    function refresh(): void {
        if (!configured) return
        resolvePlace(where => {
            if (!where) {
                error = "no location configured"
                return
            }
            const imperial = cfg.units === "imperial"
            const url = "https://api.open-meteo.com/v1/forecast?" + Http.query({
                latitude: String(where.latitude),
                longitude: String(where.longitude),
                current: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code",
                daily: "weather_code,temperature_2m_max,temperature_2m_min",
                // The API works the zone out from the coordinates, which makes
                // "today" the right day for a forecast somewhere else.
                timezone: "auto",
                forecast_days: String(root.days),
                temperature_unit: imperial ? "fahrenheit" : "celsius",
                wind_speed_unit: imperial ? "mph" : "kmh",
            })
            Http.getJson(url, (failure, data) => {
                if (failure || !data?.current) {
                    error = failure || "unexpected answer"
                    console.error(`tessera: weather: ${error}`)
                    return
                }
                const current = condition(data.current.weather_code)
                now = {
                    temperature: data.current.temperature_2m,
                    apparent: data.current.apparent_temperature,
                    humidity: data.current.relative_humidity_2m,
                    wind: data.current.wind_speed_10m,
                    label: current.label,
                    icon: icon(current.icons),
                }
                forecast = data.daily.time.map((date, at) => {
                    const day = condition(data.daily.weather_code[at] ?? 0)
                    return {
                        date,
                        high: data.daily.temperature_2m_max[at] ?? 0,
                        low: data.daily.temperature_2m_min[at] ?? 0,
                        label: day.label,
                        icon: icon(day.icons),
                    }
                })
                error = ""
            })
        })
    }

    // Weather does not move fast and the service is free; a slow poll is both
    // enough and polite.
    Timer {
        running: root.configured
        repeat: true
        triggeredOnStart: true
        interval: Math.max(5, root.cfg.interval) * 60000
        onTriggered: root.refresh()
    }

    onConfiguredChanged: place = null
}
