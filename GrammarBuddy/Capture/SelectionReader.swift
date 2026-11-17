// SelectionReader.swift
// Reading the selection from the front app (design §4.4, §5.1, §5.2): Word script → accessibility → clipboard.
// Rule: the panel does not appear before the read method is settled; once it appears it has the keyboard.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import GrammarBuddyKit

/// What the app layer keeps to write back later (§4.3 TargetHandle).
struct WriteHandle {
    var pid: pid_t
    var element: AXUIElement?
    var windowNumber: Int?
    var wordStart: Int?
    var wordEnd: Int?
    weak var inProcess: NSTextView?    // our own windows (onboarding demo, test window)
    var wordInfo: WordReadInfo?        // Word: everything the two-pass writer needs (docs/m0/word.md)
}

enum ReadFailure: Error {
    case noSelection, noAccessibilityPermission, pasteboardDenied, secureInput, automationDenied(String), excludedApp, neverClipboard

    var message: String {
        switch self {
        case .noSelection: return L.t("没有读到选中的文字。请先选中再按快捷键，⌘A 可以全选。也可以直接在这里输入。",
                                      "No selected text was found. Select some text and press the shortcut again (⌘A selects all), or type here.")
        case .noAccessibilityPermission: return L.t("还没有允许 GrammarBuddy 读取选中的文字（辅助功能权限）。", "GrammarBuddy isn't allowed to read selected text yet (Accessibility permission).")
        case .pasteboardDenied: return L.t("系统拒绝了 GrammarBuddy 读取剪贴板。", "macOS denied GrammarBuddy access to the clipboard.")
        case .secureInput: return L.t("有 App 开启了安全输入（例如密码框），这时不能读取。", "An app has Secure Input on (for example a password field), so text can't be read now.")
        case .automationDenied(let app): return L.t("没有允许 GrammarBuddy 控制 \(app)。", "GrammarBuddy isn't allowed to control \(app).")
        case .excludedApp: return L.t("这个 App 在「不处理的 App」里。", "This app is in the “Don't process” list.")
        case .neverClipboard: return L.t("这个 App 只能用剪贴板方式读取，而你打开了「从不使用剪贴板方式」。", "This app can only be read through the clipboard, and “Never use the clipboard” is on.")
        }
    }
}

struct ReadOutcome {
    var capture: Capture
    var handle: WriteHandle
    var bounds: CGRect?
    var windowFrame: CGRect?
}

@MainActor
enum SelectionReader {
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func read(app: NSRunningApplication) async -> Result<ReadOutcome, ReadFailure> {
        let bundle = app.bundleIdentifier ?? ""
        let target = TargetApp(bundleID: bundle, name: app.localizedName ?? bundle, pid: app.processIdentifier)
        let profile = AppProfiles.profile(for: bundle)
        if profile.excluded { return .failure(.excludedApp) }
        if profile.reader == .word { return await WordBridge.read(target: target) }
        guard hasAccessibility else { return .failure(.noAccessibilityPermission) }

        // Chromium / Electron: ask for the accessibility tree first; when it answers, no clipboard is needed
        if profile.reader == .clipboard { AXTree.enable(app) }
        if let ax = readAX(pid: app.processIdentifier, target: target, profile: profile) {
            if case .success = ax { return ax }
            if profile.reader != .clipboard { return ax }
        }
        if AppState.shared.neverUseClipboard { return .failure(.neverClipboard) }
        if IsSecureEventInputEnabled() { return .failure(.secureInput) }
        return await readClipboard(target: target, profile: profile)
    }

    // MARK: accessibility (§5.1 item 2)

    static func readAX(pid: pid_t, target: TargetApp, profile: AppProfile) -> Result<ReadOutcome, ReadFailure>? {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.5)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused, CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        let el = f as! AXUIElement
        AXUIElementSetMessagingTimeout(el, 0.4)      // 0.15 s expired under load and the read fell through to "no selection"
        if stringAttr(el, kAXSubroleAttribute) == (kAXSecureTextFieldSubrole as String) { return .failure(.secureInput) }
        guard let text = stringAttr(el, kAXSelectedTextAttribute), !text.isEmpty else { return nil }
        var range: NSRange?
        var rv: CFTypeRef?
        if AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rv) == .success, let rv,
           CFGetTypeID(rv) == AXValueGetTypeID() {
            var cf = CFRange()
            if AXValueGetValue(rv as! AXValue, .cfRange, &cf) { range = NSRange(location: cf.location, length: cf.length) }
        }
        var settable: DarwinBoolean = false
        let valueSettable = AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
        let role = stringAttr(el, kAXRoleAttribute) ?? ""
        let editable: Editability = valueSettable ? .editable : (role == (kAXStaticTextRole as String) ? .readOnly : .unknown)
        let bounds: CGRect? = range.flatMap { TextGeometry.bounds(el, $0) }
        // §5.1: read the selection's attributes. One font and no links = nothing to lose, so it counts as plain.
        // (Before this, every accessibility read was "unknown", which made ⏎ copy everywhere, even in a .txt file.)
        let (richness, formatCount) = range.map { Self.richness(el, $0) } ?? (.unknown, nil)
        let rich: RichText = profile.richText ?? richness
        var cap = Capture(raw: text, via: .accessibility, editability: profile.readOnly ? .readOnly : editable, richText: rich,
                          range: range, app: target)
        if range == nil { cap.editability = cap.editability == .editable ? .unknown : cap.editability }
        if rich == .rich { cap.formattingCount = formatCount }
        return .success(ReadOutcome(capture: cap, handle: WriteHandle(pid: target.pid, element: el), bounds: bounds, windowFrame: focusedWindowFrame(appEl)))
    }

    /// Formatting inside the selected range, from AXAttributedStringForRange: distinct fonts and links.
    /// Returns .unknown when the app doesn't support the attribute.
    static func richness(_ el: AXUIElement, _ r: NSRange) -> (RichText, Int?) {
        var cf = CFRange(location: r.location, length: min(r.length, 2000))   // enough to judge, and fast
        guard let v = AXValueCreate(.cfRange, &cf) else { return (.unknown, nil) }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXAttributedStringForRangeParameterizedAttribute as CFString, v, &out) == .success,
              let attr = out as? NSAttributedString, attr.length > 0 else { return (.unknown, nil) }
        var fonts = Set<String>(), links = 0, runs = 0
        attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length)) { a, range, _ in
            // whitespace-only runs often carry a fallback font; they don't count as formatting
            if attr.attributedSubstring(from: range).string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            runs += 1
            for (k, val) in a {
                let key = k.rawValue
                if key == "AXFont", let d = val as? [String: Any] {
                    // Size and bold / italic, not the family: Chinese next to "[12]" uses a fallback font, which is not formatting.
                    let name = ("\(d["AXFontName"] ?? "")").lowercased()
                    let bold = ["bold", "semibold", "heavy", "black", "medium"].contains { name.contains($0) }
                    let italic = name.contains("italic") || name.contains("oblique")
                    fonts.insert("\(d["AXFontSize"] ?? "")|\(bold)|\(italic)")
                } else if key == "AXLink" || key == "AXNaturalLanguageLink" || key == "AXUnderline" || key == "AXStrikethrough" || key == "AXSuperscript" {
                    links += 1      // links, underline, strikethrough, super/subscript would all be lost
                }
            }
        }
        let extraFonts = max(0, fonts.count - 1)
        return links > 0 || extraFonts > 0 ? (.rich, links + extraFonts) : (.plain, nil)
    }

    static func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
        return v as? String
    }

    static func focusedWindowFrame(_ appEl: AXUIElement) -> CGRect? {
        var w: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &w) == .success, let w else { return nil }
        let win = w as! AXUIElement
        var p: CFTypeRef?, s: CFTypeRef?
        AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &p)
        AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &s)
        var pt = CGPoint.zero, sz = CGSize.zero
        if let p { AXValueGetValue(p as! AXValue, .cgPoint, &pt) }
        if let s { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
        return sz == .zero ? nil : CGRect(origin: pt, size: sz)
    }

    // MARK: clipboard (§5.2)

    static func readClipboard(target: TargetApp, profile: AppProfile) async -> Result<ReadOutcome, ReadFailure> {
        let pb = NSPasteboard.general
        if #available(macOS 15.4, *) {
            if pb.accessBehavior == .alwaysDeny { return .failure(.pasteboardDenied) }
        }
        // wait for the shortcut's modifier keys to be released (max 500 ms)
        for _ in 0..<25 where !NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        let saved = Pasteboard.save(pb)
        let before = pb.changeCount
        Keys.post(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        var waited = 0
        while pb.changeCount == before && waited < 1500 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            waited += 30
        }
        let text = pb.changeCount != before ? pb.string(forType: .string) : nil
        let html = pb.changeCount != before ? pb.string(forType: .html) : nil
        Pasteboard.restore(pb, saved)          // restore right away (§5.2 step 6)
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.noSelection) }
        var cap = Capture(raw: text, via: .clipboard, editability: profile.readOnly ? .readOnly : .unknown,
                          richText: profile.richText ?? richFromHTML(html), app: target)
        cap.formattingCount = html.map(countFormatting)
        if profile.emptyCopyCopiesLine { cap.notes.append(.maybeWholeLine) }
        if saved.lostLazyData { cap.notes.append(.unsavedPasteboardData) }
        let appEl = AXUIElementCreateApplication(target.pid)
        return .success(ReadOutcome(capture: cap, handle: WriteHandle(pid: target.pid), bounds: nil, windowFrame: focusedWindowFrame(appEl)))
    }

    /// Many apps put HTML on the pasteboard even for plain text; only real formatting tags count (§5.1).
    static func richFromHTML(_ html: String?) -> RichText {
        guard let html else { return .plain }
        return countFormatting(html) > 0 ? .rich : .plain
    }

    static func countFormatting(_ html: String) -> Int {
        let re = try! NSRegularExpression(pattern: "<(a\\s|b>|b\\s|strong|em>|em\\s|i>|i\\s|u>|img|mark)", options: .caseInsensitive)
        return re.numberOfMatches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
    }
}

// MARK: pasteboard save / restore

struct SavedPasteboard {
    var items: [[NSPasteboard.PasteboardType: Data]]
    var lostLazyData: Bool
    var hadConcealed: Bool
}

enum Pasteboard {
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func save(_ pb: NSPasteboard) -> SavedPasteboard {
        var lost = false
        let items: [[NSPasteboard.PasteboardType: Data]] = (pb.pasteboardItems ?? []).map { item in
            var d: [NSPasteboard.PasteboardType: Data] = [:]
            for t in item.types { if let v = item.data(forType: t) { d[t] = v } else { lost = true } }
            return d
        }
        return SavedPasteboard(items: items, lostLazyData: lost, hadConcealed: pb.types?.contains(concealed) ?? false)
    }

    static func restore(_ pb: NSPasteboard, _ s: SavedPasteboard) {
        pb.clearContents()
        let items = s.items.map { dict -> NSPasteboardItem in
            let it = NSPasteboardItem()
            for (t, v) in dict { it.setData(v, forType: t) }
            return it
        }
        if let first = items.first {
            first.setData(Data(), forType: transient)
            if s.hadConcealed { first.setData(Data(), forType: concealed) }
        }
        pb.writeObjects(items)
    }

    /// Our own writes (paste result) carry the "don't record" markers (§8).
    static func writeTransient(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let it = NSPasteboardItem()
        it.setString(text, forType: .string)
        it.setData(Data(), forType: transient)
        it.setData(Data(), forType: concealed)
        pb.writeObjects([it])
    }
}

enum Keys {
    static func post(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags          // only ⌘, whatever the user is still holding (§5.2 step 4)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
