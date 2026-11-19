// LanguageDirection.swift
// Design §2.5: "my languages" ordered list; first ↔ second are fixed; others go to their last target or the first.
// Detection uses NLLanguageRecognizer on the whole selection; low confidence means "ask first".

import Foundation
import NaturalLanguage

public struct Detection: Sendable, Equatable {
    public var language: String?       // BCP-47 like "en", "zh-Hans"
    public var confident: Bool
}

public enum LanguageDirection {
    /// Which language is this text in, so the direction can be chosen without asking.
    ///
    /// The system recogniser alone gets the common Chinese ⇄ English cases wrong: a Chinese sentence with English
    /// terms in it came out as Danish or English, 好的 as Traditional Chinese, OK as Polish, and anything short was
    /// "not sure", which made the panel stop and ask (probe of 24 cases, 2026-11-19). So the writing system is
    /// looked at first: it is exact, instant and needs no model.
    public static func detect(_ text: String, preferred: [String] = []) -> Detection {
        var han = 0, kana = 0, hangul = 0, latinWords = 0, inLatin = false
        for u in text.unicodeScalars {
            let v = u.value
            let isLatin = (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0x24F)
            if isLatin { if !inLatin { latinWords += 1 }; inLatin = true } else if !(v == 0x27 || v == 0x2019 || v == 0x2D) { inLatin = false }
            if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) { han += 1 }
            else if v >= 0x3040 && v <= 0x30FF { kana += 1 }
            else if v >= 0xAC00 && v <= 0xD7AF { hangul += 1 }
        }
        let myChinese = preferred.first { $0.hasPrefix("zh") }
        // Chinese: Han characters carry the sentence (about 1.7 per word) and there is no kana or hangul.
        // English names, gene symbols and product names inside a Chinese sentence don't make it English.
        if han > 0, kana == 0, hangul == 0, Double(han) / 1.7 > Double(latinWords) {
            let r = NLLanguageRecognizer()
            r.languageConstraints = [.simplifiedChinese, .traditionalChinese]
            r.processString(text)
            let script = r.dominantLanguage?.rawValue ?? "zh-Hans"
            // a few characters can't tell Simplified from Traditional (好的): take the user's own Chinese
            let lang = han < 6 ? (myChinese ?? script) : script
            return Detection(language: lang, confident: true)
        }
        let r = NLLanguageRecognizer()
        r.processString(text)
        var top = r.languageHypotheses(withMaximum: 3).sorted { $0.value > $1.value }
        guard !top.isEmpty else { return Detection(language: nil, confident: false) }
        // "my languages" only break near-ties; as priors they swamp the real signal (Spanish came out as English)
        if top.count > 1, top[0].value - top[1].value < 0.1,
           let i = top.firstIndex(where: { h in preferred.contains { base($0) == base(h.key.rawValue) } }), i > 0 {
            top.swapAt(0, i)
        }
        let first = top[0], second = top.count > 1 ? top[1].value : 0
        let short = text.count < 12
        let confident = first.value > 0.75 && first.value - second > 0.3 && !short
        // A word or two in Latin letters (OK, deadline, RNA-seq) can't be recognised; if the user works with exactly
        // one Latin-script language, that is the one, and there is no need to ask.
        if !confident, short || latinWords <= 3, latinWords > 0, han == 0, kana == 0, hangul == 0 {
            let latinMine = preferred.filter { !["zh", "ja", "ko", "ar", "he", "ru", "uk", "el", "th", "hi"].contains(String($0.prefix(2))) }
            if latinMine.count == 1 { return Detection(language: latinMine[0], confident: true) }
        }
        return Detection(language: first.key.rawValue, confident: confident)
    }

    static func base(_ code: String) -> String {
        if code.hasPrefix("zh") { return code.contains("Hant") || code.contains("TW") || code.contains("HK") ? "zh-Hant" : "zh-Hans" }
        return String(code.split(separator: "-").first ?? Substring(code))
    }

    /// Target language for a detected source.
    public static func target(source: String, mine: [String], lastTargets: [String: String]) -> String {
        guard mine.count >= 2 else { return mine.first ?? "en" }
        let s = base(source)
        let m = mine.map(base)
        if s == m[0] { return mine[1] }
        if s == m[1] { return mine[0] }
        return lastTargets[s] ?? mine[0]
    }

    public static func displayName(_ code: String) -> String {
        let loc = Locale(identifier: L.isChinese ? "zh-Hans" : "en")
        return loc.localizedString(forIdentifier: code) ?? code
    }

    /// English name for prompts ("Translate the text into French").
    public static func englishName(_ code: String) -> String {
        if base(code) == "zh-Hans" { return "Simplified Chinese" }
        if base(code) == "zh-Hant" { return "Traditional Chinese" }
        return Locale(identifier: "en").localizedString(forIdentifier: code) ?? code
    }

    /// Join hard-wrapped lines (PDF copies) before translating, only when it looks hard-wrapped (§2.5).
    public static func joinHardWraps(_ s: String) -> String {
        let paras = s.components(separatedBy: "\n\n")
        return paras.map { p -> String in
            let lines = p.components(separatedBy: "\n")
            guard lines.count > 2 else { return p }
            let lens = lines.dropLast().map(\.count)
            let avg = Double(lens.reduce(0, +)) / Double(max(lens.count, 1))
            let similar = lens.filter { abs(Double($0) - avg) < avg * 0.25 }.count >= lens.count * 2 / 3
            let hyphen = lines.dropLast().contains { $0.hasSuffix("-") }
            guard similar || hyphen else { return p }
            var out = ""
            for (i, line) in lines.enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                let listy = t.range(of: "^([-•*]|\\d+[.)])\\s", options: .regularExpression) != nil || line.hasPrefix("  ")
                if i == 0 { out = t; continue }
                if listy { out += "\n" + line; continue }   // keep the indentation of list / indented lines
                if out.hasSuffix("-") { out.removeLast(); out += t } else { out += " " + t }
            }
            return out
        }.joined(separator: "\n\n")
    }
}
