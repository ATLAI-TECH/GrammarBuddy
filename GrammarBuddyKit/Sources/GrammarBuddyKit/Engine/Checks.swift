// Checks.swift
// Mechanical checks after cleaning: protected items (design §6.4) and drift (§6.5).
// They never block; failing checks change what ⏎ does (§2.4 rule 2).

import Foundation
import NaturalLanguage

public struct CheckResult: Equatable, Sendable {
    public var protectedChanged: [String] = []     // items present in the original but missing in the result
    public var droppedWords: [String] = []         // fix only: content words deleted without a replacement
    public var paragraphsChanged = false           // fix only
    public var tooLong = false                     // > 3× the original's word count
    public var newURLOrCommand: [String] = []
    public var empty = false
    public var numberMismatch: [String] = []       // translate only: a hint, never changes ⏎
    public var languageChanged: String?            // fix / polish / tone came back in another language (round 6)
    public var addedCitations: [String] = []       // citation markers the original didn't have (e.g. [12] copied from the prompt)

    public init() {}

    /// Failing checks (affect ⏎); the translate number hint is not one of them.
    public var failed: Bool {
        !protectedChanged.isEmpty || !droppedWords.isEmpty || paragraphsChanged || tooLong || !newURLOrCommand.isEmpty || empty
            || languageChanged != nil || !addedCitations.isEmpty
    }

    /// One sentence for the bottom bar and VoiceOver (§2.4 confirmation text).
    public var summary: String {
        var parts: [String] = []
        if empty { parts.append(L.t("结果是空的", "the result is empty")) }
        if let l = languageChanged { parts.append(L.t("结果换成了另一种语言（\(l)）", "the result is in another language (\(l))")) }
        if !addedCitations.isEmpty { parts.append(L.t("多出了原文没有的引用标记：", "citation markers were added: ") + addedCitations.joined(separator: " ")) }
        if !droppedWords.isEmpty {
            parts.append(L.t("删掉了原文里的词：", "words were deleted: ") + droppedWords.prefix(3).joined(separator: ", "))
        }
        if !protectedChanged.isEmpty {
            parts.append(L.t("\(protectedChanged.count) 处保护内容被改动", "\(protectedChanged.count) protected item(s) changed"))
        }
        if paragraphsChanged { parts.append(L.t("段落数变了", "the number of paragraphs changed")) }
        if tooLong { parts.append(L.t("结果比原文长很多", "the result is much longer than the text")) }
        if !newURLOrCommand.isEmpty { parts.append(L.t("结果里多了链接或命令", "a new link or command appeared")) }
        return parts.joined(separator: L.t("；", "; "))
    }
}

public enum Checks {
    static let protectPattern = try! NSRegularExpression(pattern:
        "`[^`]+`|\\[\\[[^\\]]+\\]\\]|\\[[^\\]]+\\]\\([^)]+\\)|https?://\\S+|\\[\\d+(?:[,–-]\\s*\\d+)*\\]"
        + "|\\([A-Z][^()]*\\d{4}[a-z]?\\)|\\bet al\\.|[A-Za-z]+-\\d+\\w*|\\b[A-Za-z]*\\d+[A-Za-z]+\\w*"
        + "|[−–±<>]?\\d+(?:[.,]\\d+)*\\s?(?:×|°C|°|%|µ\\w+)?|[¿¡«»]")

    public static func run(original: String, result: String, operation: TextOperation, protectedWords: [String] = []) -> CheckResult {
        run(original: original, result: result, operation: operation, protectedWords: protectedWords,
            sourceLanguage: nil, targetLanguage: nil)
    }

    /// Same, with the translation's source and target languages (BCP-47, regional variants matter: "es" vs "es-MX")
    /// so numbers are parsed by each side's conventions (§6.4). Without them a number matches if either reading matches.
    public static func run(original: String, result: String, operation: TextOperation, protectedWords: [String] = [],
                           sourceLanguage: String?, targetLanguage: String?) -> CheckResult {
        var c = CheckResult()
        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { c.empty = true; return c }
        let urlCmd = try! NSRegularExpression(pattern: "https?://\\S+|\\$\\(|\\bcurl\\b|\\|\\s*sh\\b|```")
        for m in matches(urlCmd, in: result) where !original.contains(m) { c.newURLOrCommand.append(m) }
        // added citation markers ([12], (Smith et al., 2020)) – for every operation, translation included
        let cite = try! NSRegularExpression(pattern: "\\[\\d+(?:[,–-]\\s*\\d+)*\\]|\\([A-Z][^()]*\\d{4}[a-z]?\\)")
        // full-width brackets in Chinese / Japanese text are the same citation (round 7, W7-04)
        let halfWidth = { (s: String) in s.replacingOccurrences(of: "（", with: "(").replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "［", with: "[").replacingOccurrences(of: "］", with: "]").replacingOccurrences(of: "，", with: ",") }
        let squash = { (s: String) in s.replacingOccurrences(of: " ", with: "") }
        let origCites = Set(matches(cite, in: halfWidth(original)).map(squash))
        c.addedCitations = Array(Set(matches(cite, in: halfWidth(result))).filter { !origCites.contains(squash($0)) }).sorted()
        if operation == .translate {
            c.numberMismatch = numberMismatch(original, result, source: sourceLanguage, target: targetLanguage)
            c.newURLOrCommand = []      // translation keeps URLs; only real additions matter, ignored here
            return c
        }
        // protected items (§6.4); `¿ ¡` added by a fix are fine, only deletions are reported
        var missing: [String] = []
        for t in matches(protectPattern, in: original) {
            let token = t.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty && !result.contains(token) { missing.append(token) }
        }
        for w in protectedWords where original.contains(w) && !result.contains(w) { missing.append(w) }
        // identifier-like words whose case changed: FLC vs flc (§6.4)
        // compared at the same position: "FLC" → "flc" is a change even when "FLC-3" elsewhere has the same letters
        missing += caseChangedIdentifiers(original: original, result: result)
        if countEmphasis(original) != countEmphasis(result) && countEmphasis(original) > 0 { missing.append("**/_") }
        c.protectedChanged = Array(Set(missing)).sorted()
        c.languageChanged = languageChange(original: original, result: result)
        let ow = Tokenizer.tokens(original).filter(\.isWord).count
        let rw = Tokenizer.tokens(result).filter(\.isWord).count
        c.tooLong = rw > 3 * max(ow, 1) && rw > 8
        if operation == .fix {
            c.droppedWords = droppedWords(original: original, result: result)
            c.paragraphsChanged = paragraphs(original) != paragraphs(result)
        }
        return c
    }

    /// Both texts confidently detected and in different languages (zh-Hans vs zh-Hant counts as the same).
    public static func languageChange(original: String, result: String) -> String? {
        guard original.count >= 12, result.count >= 12 else { return nil }
        let a = LanguageDirection.detect(original), b = LanguageDirection.detect(result)
        guard let la = a.language, let lb = b.language, a.confident, b.confident else {
            // CJK fallback: kana in the original and none in the result means the Japanese is gone
            let kana = { (s: String) in s.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) } }
            let han = { (s: String) in s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }
            if kana(original) && !kana(result) && !han(result) { return LanguageDirection.displayName("en") }
            if han(original) && !kana(original) && !han(result) { return LanguageDirection.displayName("en") }
            return nil
        }
        let base = { (s: String) in String(s.prefix(2)) }
        return base(la) == base(lb) ? nil : LanguageDirection.displayName(lb)
    }

    static func matches(_ re: NSRegularExpression, in s: String) -> [String] {
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    /// Identifier-like words of the original whose aligned word in the result differs only in case.
    static func caseChangedIdentifiers(original: String, result: String) -> [String] {
        let a = Tokenizer.tokens(original).filter(\.isWord).map(\.text)
        let b = Tokenizer.tokens(result).filter(\.isWord).map(\.text)
        let diff = b.map { $0.lowercased() }.difference(from: a.map { $0.lowercased() })
        var removed = Set<Int>(), inserted = Set<Int>()
        for ch in diff {
            switch ch {
            case .remove(let o, _, _): removed.insert(o)
            case .insert(let o, _, _): inserted.insert(o)
            }
        }
        let keptA = a.indices.filter { !removed.contains($0) }, keptB = b.indices.filter { !inserted.contains($0) }
        var out: [String] = []
        for (i, j) in zip(keptA, keptB) where a[i] != b[j] && looksLikeIdentifier(a[i]) { out.append(a[i]) }
        return out
    }

    static func looksLikeIdentifier(_ w: String) -> Bool {
        guard w.count > 1 else { return false }
        let letters = w.filter(\.isLetter)
        if w.contains(where: \.isNumber) && !letters.isEmpty { return true }
        if letters.count >= 2 && letters.allSatisfy(\.isUppercase) { return true }      // FLC, DNA
        // camelCase / interior capital: iPhone, McGraw
        return w.dropFirst().contains(where: \.isUppercase) && w.contains(where: \.isLowercase)
    }

    static func countEmphasis(_ s: String) -> Int {
        matches(try! NSRegularExpression(pattern: "(\\*\\*|__|\\*|_)\\S[^\\n]*?\\1"), in: s).count
    }

    static func paragraphs(_ s: String) -> Int {
        s.components(separatedBy: "\n").count
    }

    static let functionWords: Set<String> = Set("""
    a an the of to in on at for and or but is are was were be been has have had do does did that this it its as by with from
    more most very much so too also both then than just really quite rather
    le la les l un une des de du d et à au aux en il elle est que qui se ne pas der die das den dem des ein eine einen einer und zu
    im am ist sind es el los las un una unos y que en es son del al se lo
    """.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))

    static let cjkParticles: Set<String> = Set(["的", "了", "地", "得", "着", "过", "吗", "呢", "吧", "啊", "は", "が", "を", "に", "で", "と", "の", "も", "へ", "や", "か", "ね", "よ"])

    static func isCJK(_ w: String) -> Bool { w.unicodeScalars.contains { $0.value >= 0x3040 } }

    /// §6.5: every word of the original is still there, replaced in place, or moved. A deleted content word is a failure.
    /// Replacements are matched per change (the run of removed/inserted words at one place), never globally,
    /// so a correction elsewhere in the sentence cannot excuse a deletion here (MODELS.md de-fix-2).
    public static func droppedWords(original: String, result: String) -> [String] {
        let a = Tokenizer.tokens(original).filter(\.isWord).map { $0.text.lowercased() }
        let b = Tokenizer.tokens(result).filter(\.isWord).map { $0.text.lowercased() }
        var removedIdx = Set<Int>(), insertedIdx = Set<Int>()
        for ch in b.difference(from: a) {
            switch ch {
            case .remove(let o, _, _): removedIdx.insert(o)
            case .insert(let o, _, _): insertedIdx.insert(o)
            }
        }
        // Moved words: removed in one place and inserted in another.
        var moved = Set<Int>(), usedInserted = Set<Int>()
        let insertedSorted = insertedIdx.sorted()
        for o in removedIdx.sorted() {
            if let k = insertedSorted.first(where: { b[$0] == a[o] && !usedInserted.contains($0) }) {
                moved.insert(o); usedInserted.insert(k)
            }
        }
        var lost: [String] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            let keepA = i < a.count && !removedIdx.contains(i)
            let keepB = j < b.count && !insertedIdx.contains(j)
            if keepA && keepB { i += 1; j += 1; continue }
            let si = i, sj = j
            var rem: [String] = [], ins: [String] = []
            while i < a.count && removedIdx.contains(i) { if !moved.contains(i) { rem.append(a[i]) }; i += 1 }
            while j < b.count && insertedIdx.contains(j) { if !usedInserted.contains(j) { ins.append(b[j]) }; j += 1 }
            if i == si && j == sj { i += 1; j += 1; continue }   // safety: should not happen
            lost += lostWords(removed: rem, inserted: ins)
        }
        // A word that was typed twice in the original ("empezar a empezar", "the the") and is still in the result
        // was a repetition being removed, not a lost word (round 8, M8-02).
        func count(_ w: String, in xs: [String]) -> Int { xs.filter { $0 == w }.count }
        lost = lost.filter { w in
            let parts = w.split(separator: " ").map(String.init)
            return !parts.allSatisfy { count($0, in: b) >= 1 && count($0, in: a) > count($0, in: b) }
        }
        return lost
    }

    /// One change: removed words are paired with the inserted words at the same place.
    static func lostWords(removed rem: [String], inserted ins: [String]) -> [String] {
        guard !rem.isEmpty else { return [] }
        var slots = ins
        var paired = [Bool](repeating: false, count: rem.count)
        // Pass 1: obvious pairs (same start, e.g. das → dass, go → goes) and merges (over night → overnight).
        for (k, w) in rem.enumerated() {
            if slots.contains(where: { $0.count > w.count && $0.contains(w) }) { paired[k] = true; continue }
            if let s = slots.firstIndex(where: { $0.prefix(2) == w.prefix(2) && w.count >= 2 }) {
                slots.remove(at: s); paired[k] = true
            }
        }
        // Pass 2: remaining content words take the remaining replacements in order.
        // Single CJK characters lost in a row are reported together ("一至"); two or more in a row
        // always count, even particles (§6.5). A lone particle (的, は) does not.
        var out: [String] = []
        var cjkRun = ""
        func flush() {
            if !cjkRun.isEmpty && !(cjkRun.count == 1 && cjkParticles.contains(cjkRun)) { out.append(cjkRun) }
            cjkRun = ""
        }
        for (k, w) in rem.enumerated() where !paired[k] {
            let cjkChar = w.count == 1 && isCJK(w)
            let function = functionWords.contains(w) || cjkParticles.contains(w) || (w.count == 1 && !isCJK(w))
            if function {
                if cjkChar { cjkRun += w } else { flush() }
                continue
            }
            if !slots.isEmpty { slots.removeFirst(); flush(); continue }
            if cjkChar { cjkRun += w; continue }
            flush()
            out.append(w)
        }
        flush()
        return out
    }

    // MARK: translation numbers (§6.4): parse by the source/target conventions and compare values

    /// Decimal separator of a language/region ("es" → ",", "es-MX" → ".", "en" → "."); nil when unknown.
    static func decimalSeparator(_ code: String?) -> String? {
        guard let code, !code.isEmpty else { return nil }
        return Locale(identifier: code).decimalSeparator
    }

    /// Numbers of the original whose value does not appear in the result; reported as written in the original.
    static func numberMismatch(_ a: String, _ b: String, source: String? = nil, target: String? = nil) -> [String] {
        let na = numbers(in: a, decimal: decimalSeparator(source))
        guard !na.isEmpty else { return [] }
        let nb = numbers(in: b, decimal: decimalSeparator(target))
        let vb = Set(nb.flatMap(\.values))
        var out: [String] = []
        for n in na where n.values.isDisjoint(with: vb) && !out.contains(n.text) {
            // "2.0", "3.14", "v1.2": copied literally and not shaped like a thousands group ("1.400") → the same number
            let groupLike = n.text.range(of: "[.,]\\d{3}(?!\\d)", options: .regularExpression) != nil
            if !groupLike && n.text.contains(".") && !n.text.contains(",") && b.contains(n.text) { continue }
            // one- and two-digit whole numbers are often spelled out or part of a time ("14h30" → "2:30 pm", "8" → "eight")
            if n.text.count <= 2 && n.text.allSatisfy(\.isNumber) {
                // part of a clock time in the original ("14h30", "14:30", "8 h"): formats differ between languages
                if a.range(of: "(?<!\\d)\(n.text)\\s?[h:]\\s?\\d{0,2}|\\d{1,2}\\s?[h:]\\s?\(n.text)(?!\\d)", options: .regularExpression) != nil { continue }
                // spelled out in the translation: fewer figures there than here ("8" → "eight")
                if nb.count < na.count { continue }
            }
            out.append(n.text)
        }
        return out
    }

    /// Number words after a figure (E5-01): "1.400 millones" = 1.4 billion. Long scale (es billones) is 10^12.
    static func scale(after s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces)
        let table: [(String, Double)] = [
            ("mil millones", 1e9), ("billones", 1e12), ("billón", 1e12), ("trillion", 1e12), ("billion", 1e9), ("milliard", 1e9),
            ("milliarde", 1e9), ("mrd", 1e9), ("millones", 1e6), ("millón", 1e6), ("million", 1e6), ("mio", 1e6), ("thousand", 1e3),
            ("mil ", 1e3), ("mille", 1e3), ("tausend", 1e3), ("亿", 1e8), ("万", 1e4), ("千", 1e3),
        ]
        for (w, v) in table where t.hasPrefix(w) { return v }
        return 1
    }

    /// Each number with its possible values. With a known decimal separator there is one reading;
    /// without one, "1.400" is read both ways (1400 and 1.4) and any reading may match.
    static func numbers(in s: String, decimal: String?) -> [(text: String, values: Set<Double>)] {
        let re = try! NSRegularExpression(pattern: "\\d+(?:[.,\u{00A0}\u{202F} ]\\d{3})*(?:[.,]\\d+)?")
        var out: [(text: String, values: Set<Double>)] = []
        let ns = s as NSString
        for r in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let m = ns.substring(with: r.range)
            let after = ns.substring(from: NSMaxRange(r.range)).prefix(16).lowercased()
            let scale = Self.scale(after: String(after))
            let t = m.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
            let en = Double(t.replacingOccurrences(of: ",", with: ""))
            let eu = Double(t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
            var values = Set<Double>()
            switch decimal {
            case ".": if let en { values.insert(en) }
            case ",": if let eu { values.insert(eu) }
            default: if let en { values.insert(en) }; if let eu { values.insert(eu) }
            }
            if scale != 1 { values = Set(values.map { $0 * scale }) }
            if !values.isEmpty { out.append((m, values)) }
        }
        return out
    }
}
