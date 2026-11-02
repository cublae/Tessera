pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours, metrics and motion.
//
// Tessera draws with libadwaita's palette -- the named colours every GNOME
// application is written against -- so it sits next to them as one of them.
// Qt has no libadwaita, so the palette is kept here, and the same sources GTK
// would read are read directly:
//
//   - `~/.config/gtk-4.0/gtk.css`, where theme generators such as Stylix write
//     `@define-color window_bg_color ...` for the whole palette, and a blanket
//     `* { border-radius }` that is the only desktop-wide answer to rounding;
//   - `~/.config/gtk-4.0/settings.ini`, for the font and the animation switch;
//   - the desktop portal, for the light/dark preference and GNOME's accent.
//
// Whatever the config sets wins over all of it.
Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"

    // -- light and dark -----------------------------------------------------

    // The portal's `color-scheme`: 0 no preference, 1 prefer dark, 2 prefer light.
    property int portalScheme: 0

    readonly property bool wantDark: {
        const mode = Config.c.theme.mode
        if (mode === "dark") return true
        if (mode === "light") return false
        return portalScheme === 1
    }

    // What is actually painted. Trails `wantDark` by a moment so the screen can
    // be frozen first -- see `onWantDarkChanged`.
    property bool dark: wantDark

    // A theme change repaints every window on the same frame, which reads as
    // the whole screen blinking. niri can do better: `DoScreenTransition`
    // freezes what is on screen, waits, and fades from the frozen copy to
    // whatever is there afterwards. So the request goes out first and the
    // palette flips once niri has it; the delay has to cover the slowest
    // application following the same setting, not only this shell.
    onWantDarkChanged: {
        const ms = Config.c.theme.transition
        if (ms <= 0 || !Niri.connected) {
            dark = wantDark
            return
        }
        Niri.dispatch({ DoScreenTransition: { delay_ms: ms } }, () => flip.restart())
        flipFallback.restart()
    }

    Timer {
        id: flip

        interval: 16
        onTriggered: {
            flipFallback.stop()
            root.dark = root.wantDark
        }
    }

    // A compositor that never answers must not hold up the change itself.
    Timer {
        id: flipFallback

        interval: 120
        onTriggered: root.dark = root.wantDark
    }

    // -- palette ------------------------------------------------------------

    readonly property var adwaitaLight: ({
        window_bg_color: "#fafafb",
        window_fg_color: Qt.rgba(0, 0, 6 / 255, 0.8),
        view_bg_color: "#ffffff",
        view_fg_color: Qt.rgba(0, 0, 6 / 255, 0.8),
        card_bg_color: "#ffffff",
        card_fg_color: Qt.rgba(0, 0, 6 / 255, 0.8),
        popover_bg_color: "#ffffff",
        popover_fg_color: Qt.rgba(0, 0, 6 / 255, 0.8),
        headerbar_bg_color: "#ffffff",
        accent_bg_color: "#3584e4",
        accent_fg_color: "#ffffff",
        accent_color: "#1c71d8",
        destructive_color: "#c01c28",
        destructive_bg_color: "#e01b24",
        destructive_fg_color: "#ffffff",
        success_color: "#1b8553",
        warning_color: "#9c6e03",
        shade_color: Qt.rgba(0, 0, 6 / 255, 0.07),
        borders: Qt.rgba(0, 0, 6 / 255, 0.15),
    })

    readonly property var adwaitaDark: ({
        window_bg_color: "#222226",
        window_fg_color: "#ffffff",
        view_bg_color: "#1d1d20",
        view_fg_color: "#ffffff",
        card_bg_color: Qt.rgba(1, 1, 1, 0.08),
        card_fg_color: "#ffffff",
        popover_bg_color: "#36363a",
        popover_fg_color: "#ffffff",
        headerbar_bg_color: "#2e2e32",
        accent_bg_color: "#3584e4",
        accent_fg_color: "#ffffff",
        accent_color: "#78aeed",
        destructive_color: "#ff7b63",
        destructive_bg_color: "#c01c28",
        destructive_fg_color: "#ffffff",
        success_color: "#8ff0a4",
        warning_color: "#f8e45c",
        shade_color: Qt.rgba(0, 0, 6 / 255, 0.25),
        borders: Qt.rgba(1, 1, 1, 0.15),
    })

    // `@define-color` rules out of the user's GTK stylesheet.
    property var gtkColors: ({})

    // GNOME's accent setting, through the portal, or null.
    property var portalAccent: null

    // The accent taken from the wallpaper, when `theme.accentFromWallpaper` asks.
    property var wallpaperAccent: null

    function named(name: string): color {
        const base = dark ? adwaitaDark : adwaitaLight
        const value = gtkColors[name]
        return value !== undefined ? value : base[name]
    }

    // The accent to override everything else with, or null to follow the desktop.
    readonly property var accentOverride: {
        const theme = Config.c.theme
        const configured = theme.accentFromWallpaper && wallpaperAccent ? wallpaperAccent : theme.accent
        if (!configured) return null
        if (!/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(configured)) {
            console.error(`tessera: theme.accent "${configured}" is not a hex colour, ignoring`)
            return null
        }
        return configured
    }

    readonly property color bg: named("window_bg_color")
    readonly property color fg: named("window_fg_color")
    readonly property color viewBg: named("view_bg_color")
    readonly property color viewFg: named("view_fg_color")
    readonly property color cardBg: named("card_bg_color")
    readonly property color popoverBg: named("popover_bg_color")
    readonly property color headerbarBg: named("headerbar_bg_color")
    readonly property color destructive: named("destructive_color")
    readonly property color warning: named("warning_color")
    readonly property color success: named("success_color")
    readonly property color shade: named("shade_color")
    readonly property color borders: named("borders")

    // `accentBg` fills buttons; `accent` tints text and icons.
    readonly property color accentBg: {
        if (accentOverride) return accentOverride
        if (gtkColors.accent_bg_color !== undefined) return gtkColors.accent_bg_color
        if (portalAccent) return portalAccent
        return named("accent_bg_color")
    }
    readonly property color accentFg: named("accent_fg_color")
    readonly property color accent: {
        if (accentOverride) return accentOverride
        if (gtkColors.accent_color !== undefined) return gtkColors.accent_color
        if (portalAccent) return dark ? Qt.lighter(portalAccent, 1.35) : Qt.darker(portalAccent, 1.15)
        return named("accent_color")
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, c.a * a)
    }

    function mix(a: color, b: color, amount: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount,
                       a.b + (b.b - a.b) * amount, a.a + (b.a - a.a) * amount)
    }

    // Panel background, at the configured opacity.
    readonly property color panelBg: alpha(bg, Math.min(1, Math.max(0, Config.c.theme.opacity)))

    // -- metrics ------------------------------------------------------------

    // The blanket radius from gtk.css, or null.
    property var gtkRadius: null

    // `theme.radius` wins; with nothing set the shell follows the user's GTK
    // stylesheet, and failing that squares everything off. Anything that is a
    // pill by design -- sliders, the unread dot -- stays one either way.
    readonly property real radius: Math.min(32, Math.max(0, Config.c.theme.radius ?? gtkRadius ?? 0))
    readonly property real radiusLg: radius
    readonly property real radiusMd: Math.max(0, radius - 4)
    readonly property real radiusSm: Math.max(0, radius - 6)

    // Base spacing unit; module padding is a multiple of it.
    readonly property real spacing: Math.min(24, Math.max(0, Config.c.theme.spacing))

    readonly property real space1: 2
    readonly property real space2: 4
    readonly property real space3: 6
    readonly property real space4: 10
    readonly property real space5: 16

    // -- type ---------------------------------------------------------------

    property string gtkFontFamily: ""
    property real gtkFontSize: 11

    readonly property string fontFamily: Config.c.theme.font || gtkFontFamily || Qt.application.font.family
    readonly property real fontSize: gtkFontSize

    readonly property real dimOpacity: 0.7

    // -- motion -------------------------------------------------------------

    // GTK's own switch, which accessibility settings and remote sessions turn
    // off. Either it or `animations.enabled` is enough to hold everything still.
    property bool systemAnimations: true

    readonly property bool animate: Config.c.animations.enabled && systemAnimations
    readonly property int duration: animate ? Math.min(1000, Math.max(0, Config.c.animations.duration)) : 0
    readonly property int fast: animate ? 150 : 0
    readonly property var easing: [0.25, 0.46, 0.45, 0.94, 1, 1]

    // -- sources ------------------------------------------------------------

    function parseColor(value: string, known: var): var {
        const text = value.trim()
        if (/^#[0-9a-fA-F]{3,8}$/.test(text)) return text
        if (text.startsWith("@")) return known[text.slice(1)]

        const rgba = /^rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*(?:,\s*([0-9.]+)\s*)?\)$/.exec(text)
        if (rgba) {
            const channels = [Number(rgba[1]), Number(rgba[2]), Number(rgba[3])]
            // Stylix writes some of these as fractions rather than bytes.
            const scale = channels.every(c => c <= 1) ? 1 : 255
            return Qt.rgba(channels[0] / scale, channels[1] / scale, channels[2] / scale,
                           rgba[4] === undefined ? 1 : Number(rgba[4]))
        }

        const alphaFn = /^alpha\(\s*(.+?)\s*,\s*([0-9.]+)\s*\)$/.exec(text)
        if (alphaFn) {
            const inner = parseColor(alphaFn[1], known)
            if (inner === undefined) return undefined
            const c = Qt.color(inner)
            return Qt.rgba(c.r, c.g, c.b, c.a * Number(alphaFn[2]))
        }

        // mix(), shade() and named CSS colours are rare in generated sheets and
        // left to the Adwaita fallback.
        return undefined
    }

    function readGtkCss(css: string): void {
        const colors = {}
        const define = /@define-color\s+([\w-]+)\s+([^;]+);/g
        let match
        while ((match = define.exec(css)) !== null) {
            const value = parseColor(match[2], colors)
            if (value !== undefined) colors[match[1]] = value
        }
        gtkColors = colors

        // The last blanket rule wins, the same way it would in the cascade.
        const rule = /(^|[},])\s*\*\s*\{[^}]*?border-radius:\s*([0-9]+(?:\.[0-9]+)?)px/g
        let radius = null
        while ((match = rule.exec(css)) !== null) radius = Number(match[2])
        gtkRadius = radius
    }

    function readSettings(ini: string): void {
        const font = /^\s*gtk-font-name\s*=\s*(.+?)\s*$/m.exec(ini)
        if (font) {
            const parts = /^(.*?)\s+(\d+(?:\.\d+)?)$/.exec(font[1])
            gtkFontFamily = parts ? parts[1].replace(/,$/, "") : font[1]
            if (parts) gtkFontSize = Number(parts[2])
        }

        const animations = /^\s*gtk-enable-animations\s*=\s*(\S+)/m.exec(ini)
        if (animations) systemAnimations = !/^(0|false)$/i.test(animations[1])
    }

    FileView {
        path: root.configHome + "/gtk-4.0/gtk.css"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readGtkCss(text())
        onLoadFailed: {
            root.gtkColors = {}
            root.gtkRadius = null
        }
    }

    FileView {
        path: root.configHome + "/gtk-4.0/settings.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readSettings(text())
    }

    // The portal speaks GVariant text: `(<<uint32 1>>,)` for the scheme and
    // `(<<(0.2, 0.5, 0.9)>>,)` for the accent.
    function readPortal(key: string, reply: string): void {
        if (key === "color-scheme") {
            const scheme = /uint32 (\d+)/.exec(reply)
            if (scheme) portalScheme = Number(scheme[1])
        } else if (key === "accent-color") {
            const rgb = /\(\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)\s*\)/.exec(reply)
            const values = rgb ? [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])] : null
            // Out-of-range channels are the portal saying "no accent set".
            portalAccent = values && values.every(v => v >= 0 && v <= 1) ? Qt.rgba(values[0], values[1], values[2], 1) : null
        }
    }

    Process {
        id: readScheme

        running: true
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: root.readPortal("color-scheme", text)
        }
    }

    Process {
        id: readAccent

        running: true
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop",
            "--method", "org.freedesktop.portal.Settings.ReadOne", "org.freedesktop.appearance", "accent-color"]
        stdout: StdioCollector {
            onStreamFinished: root.readPortal("accent-color", text)
        }
    }

    // `SettingChanged` arrives as one line per change:
    //   /org/freedesktop/portal/desktop: org.freedesktop.portal.Settings.SettingChanged
    //     ('org.freedesktop.appearance', 'color-scheme', <uint32 1>)
    Process {
        running: true
        command: ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.portal.Desktop",
            "--object-path", "/org/freedesktop/portal/desktop"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("org.freedesktop.appearance") === -1) return
                if (line.indexOf("'color-scheme'") !== -1) root.readPortal("color-scheme", line)
                else if (line.indexOf("'accent-color'") !== -1) root.readPortal("accent-color", line)
            }
        }
    }
}
