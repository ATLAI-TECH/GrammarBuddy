// WordDiff.swift
// Word-level diff with UTF-16 offsets (design §4.2 Diff/, §2.2 per-change accept/reject).
// Tokens come from NLTokenizer so Chinese and Japanese are split into words, not single characters.

import Foundation
import NaturalLanguage

public struct Token: Equatable, Sendable {
    public var text: String
    public var range: NSRange          // UTF-16, in the source string
    public var isWord: Bool
}

public enum Tokenizer {
    /// Words from NLTokenizer; everything between words becomes whitespace runs and single punctuation tokens.
    public static func tokens(_ s: String) -> [Token] {
        let ns = s as NSString
        var out: [Token] = []
        let tk = NLTokenizer(unit: .word)
        tk.string = s
        var cursor = s.startIndex
        func gap(_ upTo: String.Index) {
            var i = cursor
            while i < upTo {
                let c = s[i]
                if c.isWhitespace {
                    var j = s.index(after: i)
                    while j < upTo, s[j].isWhitespace { j = s.index(after: j) }
                    out.append(Token(text: String(s[i..<j]), range: NSRange(i..<j, in: s), isWord: false))
                    i = j
                } else {
                    let j = s.index(after: i)
                    out.append(Token(text: String(s[i..<j]), range: NSRange(i..<j, in: s), isWord: false))
                    i = j
                }
            }
        }
        tk.enumerateTokens(in: s.startIndex..<s.endIndex) { r, _ in
            gap(r.lowerBound)
            out.append(Token(text: String(s[r]), range: NSRange(r, in: s), isWord: true))
            cursor = r.upperBound
            return true
        }
        gap(s.endIndex)
        _ = ns
        return out
    }
}

/// One change between original and result. `range` is in the original (UTF-16).
public struct Change: Identifiable, Equatable, Sendable {
    public var id: Int
    public var range: NSRange
    public var removed: String
    public var inserted: String
    public var accepted: Bool = true
    public var flags: Set<Flag> = []

    public enum Flag: String, Sendable { case protected, inQuote, skippedInWord, moved }

    public var kind: Kind { removed.isEmpty ? .insert : inserted.isEmpty ? .delete : .replace }
    public enum Kind: Sendable { case insert, delete, replace }

    /// "Their → There", spoken and shown in lists (§3).
    public var label: String {
        switch kind {
        case .insert: return "+ \(inserted.visibleWhitespace)"
        case .delete: return "− \(removed.visibleWhitespace)"
        case .replace: return "\(removed.visibleWhitespace) → \(inserted.visibleWhitespace)"
        }
    }
}

extension String {
    /// Whitespace changes are shown with visible symbols (§2.2).
    public var visibleWhitespace: String {
        var s = ""
        for ch in self {
            switch ch {
            case " ": s += "␣"
            case "\u{00A0}": s += "⍽"
            case "\u{202F}": s += "⍽"
            case "\n": s += "↵"
            case "\t": s += "⇥"
            default: s.append(ch)
            }
        }
        return s
    }
}

public enum WordDiff {
    /// Minimal token-level diff; neighbouring edits separated only by whitespace are merged into one change.
    public static func changes(from a: String, to b: String) -> [Change] {
        let ta = Tokenizer.tokens(a), tb = Tokenizer.tokens(b)
        let diff = tb.map(\.text).difference(from: ta.map(\.text))
        var removedIdx = Set<Int>(), insertedIdx = Set<Int>()
        for c in diff {
            switch c {
            case .remove(let o, _, _): removedIdx.insert(o)
            case .insert(let o, _, _): insertedIdx.insert(o)
            }
        }
        // Walk both token lists in step; collect runs of removed/inserted tokens.
        var out: [Change] = []
        var i = 0, j = 0
        let ua = a as NSString, ub = b as NSString
        while i < ta.count || j < tb.count {
            let keepA = i < ta.count && !removedIdx.contains(i)
            let keepB = j < tb.count && !insertedIdx.contains(j)
            if keepA && keepB { i += 1; j += 1; continue }
            let startA = i, startB = j
            while i < ta.count && removedIdx.contains(i) { i += 1 }
            while j < tb.count && insertedIdx.contains(j) { j += 1 }
            if i == startA && j == startB { // safety: should not happen
                if i < ta.count { i += 1 }; if j < tb.count { j += 1 }
                continue
            }
            let locA = startA < ta.count ? ta[startA].range.location : ua.length
            let endA = i > startA ? NSMaxRange(ta[i - 1].range) : locA
            let locB = startB < tb.count ? tb[startB].range.location : ub.length
            let endB = j > startB ? NSMaxRange(tb[j - 1].range) : locB
            out.append(Change(id: out.count, range: NSRange(location: locA, length: endA - locA),
                              removed: ua.substring(with: NSRange(location: locA, length: endA - locA)),
                              inserted: ub.substring(with: NSRange(location: locB, length: endB - locB))))
        }
        return merge(out, in: a)
    }

    /// Merge changes separated only by a single whitespace token (so "w̶o̶r̶k̶ works better" reads as one edit).
    static func merge(_ cs: [Change], in a: String) -> [Change] {
        guard cs.count > 1 else { return cs }
        let ns = a as NSString
        var out: [Change] = [cs[0]]
        for c in cs.dropFirst() {
            var last = out[out.count - 1]
            let gapRange = NSRange(location: NSMaxRange(last.range), length: c.range.location - NSMaxRange(last.range))
            let gap = gapRange.length >= 0 ? ns.substring(with: gapRange) : "x"
            // Neighbours separated by one space are one edit ("por que → porque" came out as "delete por" plus
            // "que → porque"; accepting only one of the two broke the sentence. Round 7, M7-02).
            if gap.isEmpty || (gap.count == 1 && gap.first!.isWhitespace && gap != "\n") {
                last.range = NSRange(location: last.range.location, length: NSMaxRange(c.range) - last.range.location)
                last.removed = ns.substring(with: last.range)
                last.inserted = last.inserted + gap + c.inserted
                out[out.count - 1] = last
            } else {
                out.append(c)
            }
        }
        return out.enumerated().map { var c = $1; c.id = $0; return c }
    }

    /// The text after applying only the accepted changes.
    public static func apply(_ changes: [Change], to a: String) -> String {
        let s = NSMutableString(string: a)
        for c in changes.sorted(by: { $0.range.location > $1.range.location }) where c.accepted {
            s.replaceCharacters(in: c.range, with: c.inserted)
        }
        return s as String
    }
}
