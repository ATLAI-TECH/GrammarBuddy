// WordMap.swift
// Pure logic of the Word writer, ported from qa/m0/word/{wordpos.py, gbword.py} (verified on Word 16.114.4,
// docs/m0/word.md): parse the script records, map UTF-16 offsets of the text read to Word positions,
// decide which changes are skipped (§2.8 + M0 recommendations) and build the write plan.
// No AppKit / AppleScript here so it can be exercised by a plain swiftc harness.

import Foundation
import NaturalLanguage
#if canImport(GrammarBuddyKit)
import GrammarBuddyKit
#endif

/// Filled by WordBridge.read; see docs/m0/word.md.
final class WordReadInfo {
    var docName = ""
    var fullName = ""
    var storyType = ""
    var trackRevisions = false
    var readOnly = false
    var protection = ""
    var start = 0
    var end = 0
    var text = ""                      // exactly as read (\r, \r\u{7}, \u{2}, \u{b} kept); sent back for the whole-range check
    var leading = 0                    // UTF-16 length of capture.leading: offset in capture.text + leading = offset in `text`
    var positions: [Int] = []          // Word position of each UTF-16 unit of `text`, plus the end
    var revisions: [(type: String, start: Int, end: Int)] = []
    var fields: [(codeStart: Int, codeEnd: Int, resultStart: Int, resultEnd: Int)] = []
    var comments: [(start: Int, end: Int)] = []
    var footnotes: [Int] = []
    var tables: [(start: Int, end: Int)] = []
    var writtenRanges: [(Int, Int)] = []   // EDIT records of the last write, for "undo this change"
    var writtenPlain: [(start: Int, new: String, old: String)] = []   // direct replacements of the last write, for undo
    var error: String?                     // ERROR record of read_selection (view pinning or text read failed)
}

enum WordMap {
    static let RS: Character = "\u{1e}", FS: Character = "\u{1f}"

    /// Records of the M0 scripts: ASCII 30 between records, ASCII 31 between fields.
    static func records(_ s: String) -> [[String]] {
        s.split(separator: RS, omittingEmptySubsequences: true).map { $0.split(separator: FS, omittingEmptySubsequences: false).map(String.init) }
    }

    /// Parse read_selection.applescript output (see the header of that script).
    static func parseRead(_ out: String) -> WordReadInfo {
        let info = WordReadInfo()
        for r in records(out) {
            let n = r.dropFirst().map { Int($0) ?? 0 }
            switch r[0] {
            case "DOC" where r.count >= 9:
                info.docName = r[1]; info.fullName = r[2]; info.storyType = r[3]
                info.start = Int(r[4]) ?? 0; info.end = Int(r[5]) ?? 0
                info.trackRevisions = r[6] == "true"; info.readOnly = r[7] == "true"; info.protection = r[8]
            case "TEXT": info.text = r.dropFirst().joined(separator: String(FS))
            case "FIELD" where r.count >= 6: info.fields.append((n[1], n[2], n[3], n[4]))
            case "REV" where r.count >= 4: info.revisions.append((r[1], n[1], n[2]))
            case "FN" where r.count >= 2: info.footnotes.append(n[0])
            case "CM" where r.count >= 3: info.comments.append((n[0], n[1]))
            case "TBL" where r.count >= 3: info.tables.append((n[0], n[1]))
            case "ERROR": info.error = r.dropFirst().joined(separator: " ")
            default: break
            }
        }
        let dels = info.revisions.filter { $0.type.contains("delete") }.map { ($0.start, $0.end) }
        info.positions = buildMap(info.text, start: info.start,
                                  hidden: hiddenIntervals(fields: info.fields.map { ($0.codeStart, $0.resultStart, $0.resultEnd) }, deletions: dels))
        return info
    }

    // MARK: position mapping (wordpos.py)

    /// Word positions that are not in the text read: per field [codeStart-1, resultStart) and [resultEnd, resultEnd+1);
    /// the text of pending deletions. Sorted and merged.
    static func hiddenIntervals(fields: [(codeStart: Int, resultStart: Int, resultEnd: Int)], deletions: [(Int, Int)]) -> [(Int, Int)] {
        var iv: [(Int, Int)] = []
        for f in fields { iv.append((f.codeStart - 1, f.resultStart)); iv.append((f.resultEnd, f.resultEnd + 1)) }
        iv += deletions
        iv.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
        var merged: [(Int, Int)] = []
        for (a, b) in iv {
            if let last = merged.last, a <= last.1 { merged[merged.count - 1].1 = max(last.1, b) }
            else { merged.append((a, b)) }
        }
        return merged
    }

    /// pos[i] = Word position of UTF-16 unit i of `content`; count = utf16 count + 1 (last = end).
    /// Every unit is one position, except "\r\u{7}" (end of cell / row) = 2 units, 1 position.
    static func buildMap(_ content: String, start: Int, hidden: [(Int, Int)]) -> [Int] {
        let cu = Array(content.utf16)
        let hi = hidden.filter { $0.1 > start }
        var pos: [Int] = []
        pos.reserveCapacity(cu.count + 1)
        var p = start, k = 0, i = 0
        func skip() {
            while k < hi.count && hi[k].0 <= p {
                if p < hi[k].1 { p = hi[k].1 }
                k += 1
            }
        }
        while i < cu.count {
            skip()
            if cu[i] == 0x0D && i + 1 < cu.count && cu[i + 1] == 0x07 {
                pos += [p, p]; i += 2; p += 1
            } else {
                pos.append(p); i += 1; p += 1
            }
        }
        skip()
        pos.append(p)
        return pos
    }

    /// UTF-16 [i, j) of the text read → Word (start, end).
    static func wordRange(_ pos: [Int], _ i: Int, _ j: Int) -> (Int, Int) {
        (pos[i], j > i ? pos[j - 1] + 1 : pos[i])
    }

    // MARK: display text

    /// What the panel shows and the model sees: same UTF-16 length as `raw`, so offsets carry over 1:1.
    /// "\r\u{7}" (cell / row end) → "\n ", "\r" and "\u{b}" (line break) → "\n". The footnote mark \u{2} stays.
    static func display(_ raw: String) -> String {
        let cu = Array(raw.utf16)
        var out: [UInt16] = []
        out.reserveCapacity(cu.count)
        var i = 0
        while i < cu.count {
            if cu[i] == 0x0D && i + 1 < cu.count && cu[i + 1] == 0x07 { out += [0x0A, 0x20]; i += 2; continue }
            out.append(cu[i] == 0x0D || cu[i] == 0x0B ? 0x0A : cu[i])
            i += 1
        }
        return String(decoding: out, as: UTF16.self)
    }

    // MARK: skip rules (§2.8 + docs/m0/word.md recommendations 2, 4, 7)

    /// Change index → reason it is not written. Ranges of `changes` are UTF-16 in capture.text.
    /// bySentence (polish / tone): a skip spreads to every change in the same sentence.
    static func skipped(_ changes: [Change], info: WordReadInfo, bySentence: Bool = false) -> [Int: String] {
        let raw = Array(info.text.utf16)
        var out: [Int: String] = [:]
        for (idx, c) in changes.enumerated() {
            if let why = reason(c, info: info, raw: raw) { out[idx] = why }
        }
        guard bySentence, !out.isEmpty else { return out }
        let shown = display(info.text)
        let tk = NLTokenizer(unit: .sentence)
        tk.string = shown
        let sentences = tk.tokens(for: shown.startIndex..<shown.endIndex).map { NSRange($0, in: shown) }
        func sentence(of c: Change) -> NSRange? {
            let a = c.range.location + info.leading
            return sentences.first { a >= $0.location && a < NSMaxRange($0) } ?? sentences.last { a == NSMaxRange($0) }
        }
        let hit = out.keys.compactMap { sentence(of: changes[$0]) }
        for (idx, c) in changes.enumerated() where out[idx] == nil {
            let r = NSRange(location: c.range.location + info.leading, length: c.range.length)
            if hit.contains(where: { NSIntersectionRange($0, r).length > 0 || (r.length == 0 && r.location >= $0.location && r.location < NSMaxRange($0)) }) {
                out[idx] = L.t("同一句里有不能写入的改动", "another change in the same sentence can't be written")
            }
        }
        return out
    }

    static func reason(_ c: Change, info: WordReadInfo, raw: [UInt16]) -> String? {
        let i = c.range.location + info.leading, j = i + c.range.length
        guard i >= 0, j <= raw.count, info.positions.count == raw.count + 1 else {
            return L.t("位置对不上", "position doesn't match")
        }
        let piece = raw[i..<j]
        if piece.contains(0x02) { return L.t("含脚注标记", "contains a footnote mark") }
        if piece.contains(0x07) { return L.t("跨表格单元格", "crosses a table cell") }
        if piece.contains(0x0D) || piece.contains(0x0A) { return L.t("跨段落", "crosses a paragraph mark") }
        if piece.contains(0x0B) { return L.t("含换行符", "contains a line break") }
        if piece.contains(where: { $0 < 0x20 && $0 != 0x09 }) { return L.t("含特殊对象", "contains a special object") }
        // an insertion between the two units of a cell mark has no Word position of its own
        if i == j, i > 0, i < raw.count, raw[i - 1] == 0x0D, raw[i] == 0x07 { return L.t("跨表格单元格", "crosses a table cell") }
        if c.inserted.utf16.contains(where: { $0 < 0x20 && $0 != 0x09 }) || c.inserted.contains("\u{2028}") || c.inserted.contains("\u{2029}") {
            return L.t("会增删段落或换行", "adds a paragraph or line break")
        }
        let (ws, we) = wordRange(info.positions, i, j)
        // pending revisions: overlapping OR touching (Word merges adjacent revisions of the same author)
        if info.revisions.contains(where: { ws <= $0.end && we >= $0.start }) {
            return L.t("挨着未处理的修订", "touches a pending tracked change")
        }
        // comments: touching the scope start or end deletes / moves the comment when accepted
        if info.comments.contains(where: { (ws <= $0.start && $0.start <= we) || (ws <= $0.end && $0.end <= we) }) {
            return L.t("碰到批注范围的边界", "touches the edge of a comment")
        }
        // fields: inside the code or the result; next to the field is fine
        for f in info.fields {
            let fs = f.codeStart - 1, fe = f.resultEnd + 1
            if ws == we ? (ws > fs && ws < fe) : (ws < fe && we > fs) { return L.t("在域（引用、日期等）里", "inside a field (citation, date, …)") }
        }
        if info.footnotes.contains(where: { $0 >= ws && $0 < we }) { return L.t("含脚注标记", "contains a footnote mark") }
        return nil
    }

    // MARK: write plan (gbword.py plan/context)

    /// Edits written in one go must not touch each other either: Word merges touching revisions of the same author
    /// into one (seen in testing: "here"→"there" next to deleting " in the text" became one deletion spanning both,
    /// which reject_edits then can't attribute). Touching changes that are adjacent in the text are merged into one
    /// change; anything else that touches (overlap) is dropped. Returns (changes to write, number dropped).
    static func coalesce(_ cs: [Change], info: WordReadInfo) -> ([Change], Int) {
        var out: [Change] = [], dropped = 0, lastEnd = Int.min
        for c in cs.sorted(by: { $0.range.location < $1.range.location }) {
            let i = c.range.location + info.leading, j = i + c.range.length
            let (ws, we) = wordRange(info.positions, i, j)
            if var last = out.last, ws <= lastEnd {
                if c.range.location == NSMaxRange(last.range) {
                    last.range.length += c.range.length
                    last.removed += c.removed
                    last.inserted += c.inserted
                    out[out.count - 1] = last
                    lastEnd = max(lastEnd, we)
                } else { dropped += 1 }
                continue
            }
            out.append(c)
            lastEnd = we
        }
        return (out, dropped)
    }

    static func isWordScalar(_ s: Unicode.Scalar) -> Bool { s == "_" || CharacterSet.alphanumerics.contains(s) }

    /// Extend UTF-16 [i, j) of `text` by one word on each side (gbword.context).
    static func context(_ text: String, _ i: Int, _ j: Int) -> (Int, Int) {
        var sc: [(Unicode.Scalar, Int)] = []        // scalar, UTF-16 offset
        var off = 0
        for s in text.unicodeScalars { sc.append((s, off)); off += s.utf16.count }
        func toScalar(_ k: Int) -> Int { sc.firstIndex { $0.1 >= k } ?? sc.count }
        var a = toScalar(i), b = toScalar(j)
        while a > 0 && !isWordScalar(sc[a - 1].0) { a -= 1 }
        while a > 0 && isWordScalar(sc[a - 1].0) { a -= 1 }
        while b < sc.count && !isWordScalar(sc[b].0) { b += 1 }
        while b < sc.count && isWordScalar(sc[b].0) { b += 1 }
        return (a < sc.count ? sc[a].1 : off, b < sc.count ? sc[b].1 : off)
    }

    static func slice(_ u: [UInt16], _ i: Int, _ j: Int) -> String { String(decoding: u[i..<j], as: UTF16.self) }

    /// argv for write_edits.applescript: docName fullName mode rs re rtext, then per change s e new len cs ce ctx.
    /// `changes` must already be filtered (accepted, not skipped); they are sent in document order.
    static func writeArgs(_ changes: [Change], info: WordReadInfo, mode: String = "plain") -> [String] {
        let raw = Array(info.text.utf16)
        var args = [info.docName, info.fullName, mode, String(info.start), String(info.end), info.text]
        for c in changes.sorted(by: { $0.range.location < $1.range.location }) {
            let i = c.range.location + info.leading, j = i + c.range.length
            let (ws, we) = wordRange(info.positions, i, j)
            let (ci, cj) = context(info.text, i, j)
            let (cs, ce) = wordRange(info.positions, ci, cj)
            args += [String(ws), String(we), c.inserted, String(c.inserted.utf16.count), String(cs), String(ce), slice(raw, ci, cj)]
        }
        return args
    }

    struct WriteOutcome {
        var mismatch: (index: Int, actual: String)?
        var error: String?
        var edits: [(k: Int, start: Int, end: Int)] = []
        var revs: [(k: Int, type: String, start: Int, end: Int)] = []
        var checked = false
        var tracked = true                 // false: replaced directly, no revisions were made
        /// Edits whose revisions are not all an insert/delete inside the edit's own range (merged with a neighbour).
        var strayEdits: [Int] {
            edits.filter { e in revs.contains { $0.k == e.k && ($0.start < e.start || $0.end > e.end || !($0.type.contains("insert") || $0.type.contains("delete"))) } }.map(\.k)
        }
    }

    static func parseWrite(_ out: String) -> WriteOutcome {
        var o = WriteOutcome()
        for r in records(out) {
            let n = r.dropFirst().map { Int($0) ?? 0 }
            switch r[0] {
            case "MISMATCH": o.mismatch = (n.first ?? 0, r.dropFirst(2).joined(separator: String(FS)))
            case "ERROR": o.error = r.dropFirst().joined(separator: " ")
            case "EDIT" where r.count >= 4: o.edits.append((n[0], n[1], n[2]))
            case "REV" where r.count >= 5: o.revs.append((n[0], r[2], n[2], n[3]))
            case "CHECKED": o.checked = true
            case "MODE" where r.count >= 2: o.tracked = r[1] == "tracked"
            default: break
            }
        }
        return o
    }
}
