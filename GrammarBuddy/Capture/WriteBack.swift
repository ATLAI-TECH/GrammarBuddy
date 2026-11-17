// WriteBack.swift
// Putting the result back (design §4.5, §5.2, §5.3): accessibility whole replace with verification,
// paste with keyboard hand-off, insert below. "Confirmed unchanged" is the only result that allows a second method.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import GrammarBuddyKit

enum WriteOutcome: Equatable {
    case verified, unverified, pasted, notApplied(String)
}

@MainActor
enum WriteBack {
    static func axString(_ el: AXUIElement, _ r: NSRange) -> String? {
        var cf = CFRange(location: r.location, length: r.length)
        guard let v = AXValueCreate(.cfRange, &cf) else { return nil }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXStringForRangeParameterizedAttribute as CFString, v, &out) == .success else { return nil }
        return out as? String
    }

    static func setRange(_ el: AXUIElement, _ r: NSRange) -> Bool {
        var cf = CFRange(location: r.location, length: r.length)
        guard let v = AXValueCreate(.cfRange, &cf) else { return false }
        return AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, v) == .success
    }

    /// §5.3 whole replace. `full` = leading + new text + trailing; `oldFull` = what was read.
    static func axReplace(handle: WriteHandle, range: NSRange, oldFull: String, newFull: String) async -> WriteOutcome {
        guard let el = handle.element else { return .notApplied("unchanged") }
        // 1. the range still holds the original
        // a pure insertion has nothing to compare (some apps return nil for an empty range)
        guard range.length == 0 || axString(el, range) == oldFull else { return .notApplied(L.t("原文已经变了", "The original text has changed")) }
        // 2. set selection back and write
        _ = setRange(el, range)
        let st = AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, newFull as CFString)
        if st == .attributeUnsupported || st == .actionUnsupported || st == .illegalArgument || st == .notImplemented {
            return .notApplied("unchanged")
        }
        let newLen = (newFull as NSString).length
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            if axString(el, NSRange(location: range.location, length: newLen)) == newFull {
                _ = setRange(el, NSRange(location: range.location, length: newLen))
                return .verified
            }
        }
        if axString(el, range) == oldFull { return .notApplied("unchanged") }
        return .unverified
    }

    /// §5.3 insert below: after the end of the paragraph that holds the selection.
    static func axInsertBelow(handle: WriteHandle, range: NSRange, text: String) async -> WriteOutcome {
        guard let el = handle.element else { return .notApplied("no element") }
        var v: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
        let whole = (v as? String ?? "") as NSString
        var end = NSMaxRange(range)
        if whole.length > 0 {
            let nl = whole.rangeOfCharacter(from: .newlines, options: [], range: NSRange(location: end, length: max(0, whole.length - end)))
            end = nl.location == NSNotFound ? whole.length : nl.location
        }
        let insert = "\n" + text
        _ = setRange(el, NSRange(location: end, length: 0))
        let st = AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, insert as CFString)
        guard st == .success else { return .notApplied(L.t("这个 App 不接受插入", "This app doesn't accept the insert")) }
        try? await Task.sleep(nanoseconds: 80_000_000)
        return axString(el, NSRange(location: end, length: (insert as NSString).length)) == insert ? .verified : .unverified
    }

    /// Paste (§4.5): the panel has already given up the keyboard; check the app and window, then ⌘V.
    static func paste(_ text: String, handle: WriteHandle, unknownEditability: Bool) async -> WriteOutcome {
        guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier == handle.pid else {
            return .notApplied(L.t("原来的 App 已经不在最前面", "The original app is no longer in front"))
        }
        var clean = text.unicodeScalars.filter { $0 == "\n" || $0 == "\t" || !CharacterSet.controlCharacters.contains($0) }
            .map(String.init).joined()
        if unknownEditability { while clean.hasSuffix("\n") { clean.removeLast() } }
        let pb = NSPasteboard.general
        let saved = Pasteboard.save(pb)
        Pasteboard.writeTransient(clean)
        let ours = pb.changeCount
        Keys.post(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        let wait = max(1.0, Double(clean.count) / 4000)
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        if pb.changeCount == ours { Pasteboard.restore(pb, saved) }    // the user copied something meanwhile: leave it
        return .pasted
    }
}
