.pragma library

// strftime, for the formats the config is written in.
//
// The clock, calendar and desktop formats are strftime patterns because that is
// what people already know and what GLib took: `%H:%M`, `%A, %e %B %Y`. Qt
// speaks its own pattern language instead, so the conversion happens here,
// with names coming from the locale the way the C library's would.
//
// `%B` and `%OB` follow GLib: in languages that inflect month names, `%B` is
// the form used inside a date ("3 ноября") and `%OB` the one that stands alone
// ("ноябрь 2026"). Qt keeps the same distinction as monthName versus
// standaloneMonthName.

function pad(value, width, fill) {
    let text = String(value)
    while (text.length < width) text = fill + text
    return text
}

function dayOfYear(date) {
    const start = new Date(date.getFullYear(), 0, 1)
    return Math.floor((date - start) / 86400000) + 1
}

function offset(date) {
    const minutes = -date.getTimezoneOffset()
    const sign = minutes >= 0 ? "+" : "-"
    const abs = Math.abs(minutes)
    return sign + pad(Math.floor(abs / 60), 2, "0") + pad(abs % 60, 2, "0")
}

// Qt numbers weekdays 1..7 from Monday; JavaScript 0..6 from Sunday.
function qtDay(date) {
    const day = date.getDay()
    return day === 0 ? 7 : day
}

function format(pattern, date, locale) {
    let out = ""

    for (let i = 0; i < pattern.length; i++) {
        const char = pattern[i]
        if (char !== "%" || i === pattern.length - 1) {
            out += char
            continue
        }

        let spec = pattern[++i]
        let alternative = false
        if ((spec === "O" || spec === "E") && i < pattern.length - 1) {
            alternative = spec === "O"
            spec = pattern[++i]
        }

        const hours = date.getHours()
        const month = date.getMonth() + 1

        switch (spec) {
        case "a": out += locale.dayName(date.getDay(), 1); break
        case "A": out += locale.dayName(date.getDay(), 0); break
        case "b":
        case "h":
            out += alternative ? locale.standaloneMonthName(month - 1, 1) : locale.monthName(month - 1, 1)
            break
        case "B":
            out += alternative ? locale.standaloneMonthName(month - 1, 0) : locale.monthName(month - 1, 0)
            break
        case "d": out += pad(date.getDate(), 2, "0"); break
        case "e": out += pad(date.getDate(), 2, " "); break
        case "H": out += pad(hours, 2, "0"); break
        case "k": out += pad(hours, 2, " "); break
        case "I": out += pad(hours % 12 || 12, 2, "0"); break
        case "l": out += pad(hours % 12 || 12, 2, " "); break
        case "m": out += pad(month, 2, "0"); break
        case "M": out += pad(date.getMinutes(), 2, "0"); break
        case "S": out += pad(date.getSeconds(), 2, "0"); break
        case "p": out += hours < 12 ? locale.amText : locale.pmText; break
        case "P": out += (hours < 12 ? locale.amText : locale.pmText).toLowerCase(); break
        case "y": out += pad(date.getFullYear() % 100, 2, "0"); break
        case "Y": out += date.getFullYear(); break
        case "C": out += pad(Math.floor(date.getFullYear() / 100), 2, "0"); break
        case "j": out += pad(dayOfYear(date), 3, "0"); break
        case "u": out += qtDay(date); break
        case "w": out += date.getDay(); break
        case "s": out += Math.floor(date.getTime() / 1000); break
        case "z": out += offset(date); break
        case "Z": out += date.toLocaleTimeString(Qt.locale("C"), "t"); break
        case "F": out += format("%Y-%m-%d", date, locale); break
        case "T": out += format("%H:%M:%S", date, locale); break
        case "R": out += format("%H:%M", date, locale); break
        case "D": out += format("%m/%d/%y", date, locale); break
        case "x": out += date.toLocaleDateString(locale, 1); break
        case "X": out += date.toLocaleTimeString(locale, 1); break
        case "c": out += date.toLocaleString(locale, 1); break
        case "n": out += "\n"; break
        case "t": out += "\t"; break
        case "%": out += "%"; break
        default: out += "%" + spec
        }
    }

    return out
}
