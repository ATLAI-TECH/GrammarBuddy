// Quotes.swift
// Direct quotations: what someone actually said must not be "corrected" (round 7, M7-01: a journalist's quoted
// speech was changed by Polish, by Fix and by live check without any sign).

import Foundation

public enum Quotes {
    static let pairs: [(Character, Character)] = [("«", "»"), ("“", "”"), ("„", "“"), ("「", "」"), ("『", "』"), ("‹", "›")]

    /// UTF-16 ranges of quoted speech in `s`, including the quotation marks: paired marks, straight double quotes,
    /// and lines of dialogue that open with a dash (Spanish / French).
    public static func ranges(in s: String) -> [NSRange] {
        var out: [NSRange] = []
        let chars = Array(s)
        var utf16Offset: [Int] = []
        var acc = 0
        for c in chars { utf16Offset.append(acc); acc += String(c).utf16.count }
        utf16Offset.append(acc)
        func add(_ a: Int, _ b: Int) { out.append(NSRange(location: utf16Offset[a], length: utf16Offset[b + 1] - utf16Offset[a])) }
        var i = 0
        var straightOpen: Int?
        while i < chars.count {
            let c = chars[i]
            if let pair = pairs.first(where: { $0.0 == c }) {
                // closing mark on the same paragraph
                var j = i + 1
                while j < chars.count, chars[j] != pair.1, chars[j] != "\n" { j += 1 }
                if j < chars.count, chars[j] == pair.1 { add(i, j); i = j + 1; continue }
            } else if c == "\"" {
                if let o = straightOpen { add(o, i); straightOpen = nil } else { straightOpen = i }
            } else if c == "\n" {
                straightOpen = nil
            } else if (c == "—" || c == "–") && (i == 0 || chars[i - 1] == "\n") {
                var j = i
                while j + 1 < chars.count, chars[j + 1] != "\n" { j += 1 }
                add(i, j); i = j + 1; continue
            }
            i += 1
        }
        return out
    }

    public static func contains(_ r: NSRange, in quotes: [NSRange]) -> Bool {
        quotes.contains { q in
            r.length == 0 ? (r.location > q.location && r.location < NSMaxRange(q)) : NSIntersectionRange(q, r).length > 0
        }
    }
}
