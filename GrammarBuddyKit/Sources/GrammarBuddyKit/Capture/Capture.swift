// Capture.swift
// What was read from the other app (design §4.3). The handle to write back lives in the app layer;
// here it is an opaque token so the Kit stays free of AppKit and can be unit-tested.

import Foundation

public struct TargetApp: Sendable, Equatable {
    public var bundleID: String
    public var name: String
    public var pid: Int32
    public init(bundleID: String, name: String, pid: Int32) { self.bundleID = bundleID; self.name = name; self.pid = pid }
}

public enum CaptureSource: String, Sendable { case accessibility, clipboard, word, service, manual }
public enum Editability: String, Sendable { case editable, readOnly, unknown }
public enum RichText: String, Sendable { case plain, rich, unknown }

public enum CaptureNote: String, Sendable { case unsavedPasteboardData, maybeWholeLine, wordHasPendingRevisions }

public struct Capture: Sendable {
    public var text: String
    public var leading: String
    public var trailing: String
    public var via: CaptureSource
    public var editability: Editability
    public var richText: RichText
    public var range: NSRange?              // UTF-16, accessibility path only
    public var app: TargetApp?
    public var notes: [CaptureNote]
    public var formattingCount: Int?        // links / bold spans counted from clipboard HTML (§5.4)
    public var wordCannotWrite: String?     // Word: reason the whole selection cannot be written (§2.8)

    public init(raw: String, via: CaptureSource, editability: Editability = .unknown, richText: RichText = .unknown,
                range: NSRange? = nil, app: TargetApp? = nil, notes: [CaptureNote] = []) {
        let (l, core, t) = Capture.split(raw)
        self.text = core; self.leading = l; self.trailing = t
        self.via = via; self.editability = editability; self.richText = richText
        self.range = range; self.app = app; self.notes = notes
    }

    /// Leading/trailing whitespace is kept aside and glued back unchanged on write (§5.1).
    public static func split(_ s: String) -> (String, String, String) {
        let chars = Array(s)
        var a = 0, b = chars.count
        while a < b, chars[a].isWhitespace { a += 1 }
        while b > a, chars[b - 1].isWhitespace { b -= 1 }
        return (String(chars[0..<a]), String(chars[a..<b]), String(chars[b..<chars.count]))
    }

    public var wordCount: Int { Tokenizer.tokens(text).filter(\.isWord).count }
}
