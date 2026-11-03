.pragma library

// Material 3 colour roles, generated from one seed colour.
//
// Material builds a scheme by taking the seed's hue, making tonal palettes at
// fixed chromas, and assigning each role a fixed tone. Tone is perceptual
// lightness, which is exactly L* in CIELAB, so Lab's polar form stands in for
// Google's HCT: the hue drifts slightly from what Android would pick for the
// same seed, but the tones, and so the contrast between roles, are the same.

const D65 = [0.95047, 1, 1.08883]

function linear(channel) {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
}

function gamma(channel) {
    return channel <= 0.0031308 ? channel * 12.92 : 1.055 * Math.pow(channel, 1 / 2.4) - 0.055
}

function toLch(r, g, b) {
    const [lr, lg, lb] = [linear(r), linear(g), linear(b)]
    const xyz = [
        0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb,
        0.2126729 * lr + 0.7151522 * lg + 0.072175 * lb,
        0.0193339 * lr + 0.119192 * lg + 0.9503041 * lb,
    ]
    const [fx, fy, fz] = xyz.map((value, at) => {
        const t = value / D65[at]
        return t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116
    })
    const a = 500 * (fx - fy)
    const b2 = 200 * (fy - fz)
    return { l: 116 * fy - 16, c: Math.hypot(a, b2), h: Math.atan2(b2, a) * 180 / Math.PI }
}

// sRGB channels for an LCh colour, or null outside the gamut.
function toRgb(l, c, h) {
    const radians = h * Math.PI / 180
    const fy = (l + 16) / 116
    const fx = fy + c * Math.cos(radians) / 500
    const fz = fy - c * Math.sin(radians) / 200
    const [x, y, z] = [fx, fy, fz].map((f, at) => {
        const t = f * f * f
        return D65[at] * (t > 216 / 24389 ? t : (116 * f - 16) * 27 / 24389)
    })
    const rgb = [
        3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
        -0.969266 * x + 1.8760108 * y + 0.041556 * z,
        0.0556434 * x - 0.2040259 * y + 1.0572252 * z,
    ]
    if (rgb.some(channel => channel < -0.0005 || channel > 1.0005)) return null
    return rgb.map(channel => gamma(Math.min(1, Math.max(0, channel))))
}

// The colour at a tone, giving up chroma where the gamut runs out: near black
// and white there is little of it to be had, and the tone is what must hold.
function tone(h, c, t) {
    let low = 0
    let high = c
    let found = toRgb(t, 0, h)
    if (toRgb(t, c, h)) {
        found = toRgb(t, c, h)
    } else {
        for (let step = 0; step < 12; step++) {
            const middle = (low + high) / 2
            const rgb = toRgb(t, middle, h)
            if (rgb) {
                found = rgb
                low = middle
            } else {
                high = middle
            }
        }
    }
    return "#" + found.map(channel => Math.round(channel * 255).toString(16).padStart(2, "0")).join("")
}

// Channels are 0..1.
function scheme(r, g, b, dark) {
    const seed = toLch(r, g, b)
    // A grey seed has no meaningful hue to build on, so it stays a grey scheme
    // rather than turning whichever colour its rounding errors point at.
    const grey = seed.c < 5
    const primary = t => tone(seed.h, grey ? seed.c : 44, t)
    const secondary = t => tone(seed.h, grey ? seed.c : 18, t)
    const neutral = t => tone(seed.h, grey ? 0 : 5, t)
    const variant = t => tone(seed.h, grey ? 0 : 9, t)
    const on = (light, night) => dark ? night : light

    return {
        primary: primary(on(40, 80)),
        onPrimary: primary(on(100, 20)),
        primaryContainer: primary(on(90, 30)),
        onPrimaryContainer: primary(on(10, 90)),
        secondaryContainer: secondary(on(90, 30)),
        onSecondaryContainer: secondary(on(10, 90)),
        surface: neutral(on(98, 6)),
        surfaceContainer: neutral(on(94, 12)),
        surfaceContainerHigh: neutral(on(92, 17)),
        surfaceContainerHighest: neutral(on(90, 22)),
        onSurface: neutral(on(10, 90)),
        onSurfaceVariant: variant(on(30, 80)),
        outline: variant(on(50, 60)),
        outlineVariant: variant(on(80, 30)),
        error: tone(29, 70, on(40, 80)),
        warning: tone(85, 60, on(40, 80)),
        success: tone(145, 45, on(40, 80)),
    }
}
