.pragma library

// The shape of `~/.config/tessera/config.json`, as its defaults.
//
// This file is the single source of truth for what the shell can be told to do.
// The Home Manager module generates JSON against it, so any key added here
// should get a matching Nix option in `modules/home-manager.nix`. What every
// key means is documented in the README.

var config = {
    bar: {
        enabled: true,
        // `top`, `bottom`, `left` or `right`.
        position: "bottom",
        // Thickness in logical pixels: height when horizontal, width when vertical.
        size: 38,
        onAllMonitors: true,
        modules: {
            start: ["launcher", "clipboard", "workspaces", "media"],
            center: ["clock"],
            // `resources` is deliberately absent: a bar is a glance, and a
            // running percentage of CPU is a number to watch, not to glance at.
            // `privacy` and `screencast` cost nothing to leave in: both are
            // invisible until something actually uses the microphone, the
            // camera or the screen. An indicator you have to know about and
            // switch on is not one.
            end: ["privacy", "screencast", "recording", "tray", "keyboard-layout", "notifications", "system-indicators"],
        },
        // Layouts for single outputs, keyed by connector name. Sections left out
        // fall back to `bar.modules`; an unknown name is simply never matched.
        outputs: {},
    },
    workspaces: {
        perMonitor: true,
        showEmpty: false,
        labels: "index",
        showIcons: true,
        maxIcons: 4,
    },
    clock: {
        format: "%H:%M",
        tooltipFormat: "%A, %e %B %Y",
        verticalFormat: "%H\n%M",
    },
    calendar: {
        firstDay: "monday",
    },
    weather: {
        location: "",
        latitude: 0,
        longitude: 0,
        units: "metric",
        interval: 30,
    },
    interface: {
        language: "auto",
    },
    desktop: {
        enabled: false,
        clockFormat: "%H:%M",
        dateFormat: "%A, %e %B",
        showDate: true,
        showMedia: true,
    },
    media: {
        maxLength: 24,
    },
    resources: {
        interval: 2000,
        showCpu: true,
        showMemory: true,
        showTemperature: true,
    },
    focusedWindow: {
        maxLength: 48,
        showAppId: false,
    },
    notifications: {
        timeout: 5,
        position: "auto",
        maxPopups: 3,
        doNotDisturb: false,
    },
    launcher: {
        minScore: 0.2,
        showHidden: false,
    },
    osd: {
        timeout: 1500,
        position: "bottom",
        barRadius: null,
    },
    animations: {
        enabled: true,
        duration: 180,
    },
    audio: {
        maxVolume: 1,
    },
    screenRecord: {
        target: "portal",
        fps: 60,
        audio: "default_output",
        quality: "very_high",
        codec: "auto",
        directory: "",
    },
    clipboard: {
        manageDaemon: true,
        maxEntries: 200,
        maxVisible: 20,
        persist: true,
    },
    theme: {
        mode: "auto",
        accent: null,
        accentFromWallpaper: false,
        wallpaper: "",
        radius: null,
        transition: 250,
        spacing: 6,
        opacity: 1,
        font: "",
    },
    modules: {
        controlCenter: true,
        notifications: true,
        launcher: true,
        clipboard: true,
        osd: true,
    },
}

function isPlainObject(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value)
}

// Merge `override` onto `base`.
//
// Objects merge key by key; arrays and scalars replace wholesale. Replacing
// arrays is deliberate -- a user listing `bar.modules.start` means "these, in
// this order", not "these in addition to the defaults".
function merge(base, override) {
    if (!isPlainObject(override)) return base
    if (!isPlainObject(base)) return override

    const result = Object.assign({}, base)
    for (const key of Object.keys(override)) {
        const value = override[key]
        result[key] = isPlainObject(value) ? merge(base[key], value) : value
    }
    return result
}

// The config `text` describes, or the defaults when it describes nothing usable.
function parse(text) {
    if (!text || !text.trim()) return config
    return merge(config, JSON.parse(text))
}
