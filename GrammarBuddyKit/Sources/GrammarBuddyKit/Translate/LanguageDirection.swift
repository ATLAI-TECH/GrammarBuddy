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
    public static func detect(_ text: String, preferred: [String] = []) -> Detection {
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
