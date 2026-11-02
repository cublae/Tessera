pragma Singleton

import QtQuick
import Quickshell

import "../lib/ru.js" as Ru

// Translation.
//
// The English string is the key, the way gettext does it. Call sites stay
// readable -- `I18n.tr("Do not disturb")` says what it renders -- and an
// untranslated string falls through to something correct rather than to a
// symbolic name leaking onto the screen.
//
// Every lookup reads `catalogue`, so text bound through `tr` follows a change
// of `interface.language` without anything being rebuilt.
Singleton {
    id: root

    readonly property string language: {
        const choice = Config.c.interface.language
        if (choice === "en" || choice === "ru") return choice
        const locale = Qt.locale().name.toLowerCase()
        return locale.startsWith("ru") ? "ru" : "en"
    }

    readonly property var catalogue: language === "ru" ? Ru.ru : null

    function tr(text: string): string {
        const catalogue = root.catalogue
        if (!catalogue) return bare(text)
        const found = catalogue[text]
        return found === undefined ? bare(text) : found
    }

    // A key can carry a context suffix -- `Clear_weather` -- where the same
    // English word needs two translations. The suffix is not part of the text.
    function bare(text: string): string {
        return text.replace(/_[a-z]+$/, "")
    }

    // Plurals. Russian has three forms -- 1 минута, 2 минуты, 5 минут -- and the
    // teens all take the third, which is the part a naive `n === 1` gets wrong.
    function plural(count: int, forms: var): string {
        if (language !== "ru") return count === 1 ? forms[0] : forms[1]

        const mod10 = count % 10
        const mod100 = count % 100
        if (mod10 === 1 && mod100 !== 11) return forms[0]
        if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return forms[1]
        return forms[2]
    }
}
