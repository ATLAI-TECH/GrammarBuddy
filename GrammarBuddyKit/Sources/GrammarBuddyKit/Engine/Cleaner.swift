// Cleaner.swift
// Output cleaning (design §6.3): thinking tags, preambles, wrapping quotes, added Markdown emphasis,
// restoring non-breaking spaces, and French typography after translation (§2.5).

import Foundation

public enum Cleaner {
    static let quotePairs: [(String, String)] = [("\"", "\""), ("“", "”"), ("«", "»"), ("「", "」"), ("```", "```"), ("'", "'")]

    public static func clean(_ raw: String, original: String, operation: TextOperation, targetLanguage: String? = nil) -> String {
        var out = raw.replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
        if let open = out.range(of: "<think>") { out = String(out[..<open.lowerBound]) } // unterminated thinking
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        out = out.replacingOccurrences(
            of: "^(?i)(here is|here's|here are|sure[,!]?|corrected( text)?|the corrected text|revised( text)?|translation)[^\\n]{0,60}:\\s*\\n+",
            with: "", options: .regularExpression)
        out = stripWrappingQuotes(out, original: original)
        if !hasEmphasis(original) {
            out = out.replacingOccurrences(of: "(\\*\\*|__|\\*)(\\S(?:[^\\n]*?\\S)?)\\1", with: "$2", options: .regularExpression)
        }
        if operation != .translate { out = restoreNBSP(out, original: original) }
        // Markdown hard breaks: trailing spaces at line ends the original didn't have (T5-04)
        if !original.contains("  \n") { out = out.replacingOccurrences(of: "[ \t]+\n", with: "\n", options: .regularExpression) }
        if operation == .translate, let t = targetLanguage, t.lowercased().hasPrefix("fr") { out = frenchSpacing(out) }
        return out
    }

    static func stripWrappingQuotes(_ s: String, original: String) -> String {
        let o = original.trimmingCharacters(in: .whitespacesAndNewlines)
        // Any kind of quote around the original counts: «…» around a translation of "…" is correct (§6.3).
        if quotePairs.contains(where: { o.hasPrefix($0.0) && o.hasSuffix($0.1) && o.count > 1 }) { return s }
        for (a, b) in quotePairs where s.count > a.count + b.count && s.hasPrefix(a) && s.hasSuffix(b) {
            let inner = String(s.dropFirst(a.count).dropLast(b.count))
            if !inner.contains(a) && !inner.contains(b) {
                return inner.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return s
    }

    static func hasEmphasis(_ s: String) -> Bool {
        s.range(of: "(\\*\\*|__|\\*|_)\\S[^\\n]*?\\1", options: .regularExpression) != nil
    }

    /// The model replaced U+00A0 / U+202F with plain spaces: put them back where the neighbours match (§6.3).
    static func restoreNBSP(_ out: String, original: String) -> String {
        let specials: [Character] = ["\u{00A0}", "\u{202F}"]
        guard original.contains(where: { specials.contains($0) }) else { return out }
        var result = out
        let o = Array(original)
        for (i, ch) in o.enumerated() where specials.contains(ch) {
            let before = i > 0 ? String(o[max(0, i - 6)..<i]) : ""
            let after = i + 1 < o.count ? String(o[(i + 1)..<min(o.count, i + 3)]) : ""
            let plain = before + " " + after
            if let r = result.range(of: plain) {
                result.replaceSubrange(r, with: before + String(ch) + after)
            }
        }
        return result
    }

    /// French: no-break space inside « » and before : ; ? ! (only replacing plain spaces already there).
    static func frenchSpacing(_ s: String) -> String {
        var r = s.replacingOccurrences(of: "« ", with: "«\u{00A0}")
        r = r.replacingOccurrences(of: " »", with: "\u{00A0}»")
        r = r.replacingOccurrences(of: " ([:;?!])", with: "\u{202F}$1", options: .regularExpression)
        return r
    }
}
