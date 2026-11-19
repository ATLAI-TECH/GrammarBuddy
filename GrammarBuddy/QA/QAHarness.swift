// QAHarness.swift  (DEBUG only)
// Lets review agents drive the app without Screen Recording or Accessibility permission (design §9):
// the app screenshots its own windows and sends key / mouse events to itself. Approach from ScienceSkim.
//
// Start:  open -n GrammarBuddy.app --args -gb_qa_dir /tmp/gbqa/<name> [-gb_qa_fresh YES] [-gb_qa_no_onboarding YES]
// Drive:  write commands to <dir>/cmd (one per line or ';'-separated). When done the app deletes cmd and writes
//         <dir>/done (sequence number), <dir>/log (one line per command) and <dir>/state.json (panel state).
// Script: qa/gbqa.sh <dir> "simulate:slack-gmail; wait:8; shot:after"
//
// Commands
//   target:<panel|onboarding|settings|test>   window that key/type/click/shot use (default: panel if open, else key window)
//   key:<k>        return escape tab space up down left right delete, or a character; prefixes cmd+ opt+ shift+ ctrl+
//   type:<text>    typed into the focused text view of the target window
//   click:x,y      window coordinates in points, origin top-left (screenshots are 2x: divide by 2)
//   shot:<name>    PNG of the target window to <dir>/<name>.png; shot:<name>@all = every visible window
//   open:<onboarding|settings|settings:<tab>|test>
//   simulate:<preset or JSON>   open the panel as if text had been read from another app (writes are logged, not performed)
//        presets: textedit, slack, gmail-chrome, word, word-translate, terminal, pages, manual, noax
//        JSON: {"app":"com.tinyspeck.slackmacgap","name":"Slack","via":"clipboard","edit":"unknown","rich":"rich",
//               "text":"…","op":"fix","formatting":1,"range":true}
//   hotkey:<fix|translate>     as if the global shortcut was pressed (works on our own windows' text views)
//   select:<start>,<length>    select in the focused text view of the target window ("select:all" too)
//   panel:<action>[=<arg>]     toggle=<i>, tone=<formal…>, target=<lang>, source=<lang>, engine=<id>, op=<fix…>,
//                              allow=always|once, refuse, first=<n>, diff, retry, aiTranslate, sysTranslate, undoWord, copyList
//   set:<key>=<value>          UserDefaults (strings; true/false become Bool)
//   engine:local=<model> | engine:api=<baseURL>|<model>|<key> | engine:active=<id> | engine:clear
//   guard:<bundle id>          later front-app steps (frontselect, frontread, hotkey, key, click, type) are skipped unless that app is frontmost
//   frontselect:<start>,<len>|all   frontread     select / read text in the real front app through Accessibility
//   wait:<seconds>   focus   dump   quit

#if DEBUG
import AppKit
import Carbon.HIToolbox
import ApplicationServices
import SwiftUI
import GrammarBuddyKit

@MainActor
final class QAHarness {
    static let shared = QAHarness()
    private var dir: URL?
    private var seq = 0
    private var timer: Timer?
    private var busy = false
    private var targetName: String?
    private var lines: [String] = []
    private var requiredFront: String?

    var suppressOnboarding: Bool { UserDefaults.standard.bool(forKey: "gb_qa_no_onboarding") }

    func startIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "gb_qa_dir"), !path.isEmpty else { return }
        // own settings suite per QA directory, so parallel instances don't share engines or languages
        let suite = "atlai.GrammarBuddy.qa." + URL(fileURLWithPath: path).lastPathComponent
        Store.defaults = UserDefaults(suiteName: suite) ?? .standard
        if UserDefaults.standard.bool(forKey: "gb_qa_fresh") {
            for k in ["gb_languages", "gb_engines", "gb_active_engine", "gb_onboarded", "gb_api_allowed", "gb_local_only",
                      "gb_tone", "gb_translate_ai", "gb_protected", "gb_last_targets", "gb_never_clipboard"] {
                Store.defaults.removeObject(forKey: k)
            }
            AppState.shared.myLanguages = AppState.shared.defaultLanguages()
            Store.defaults.set(false, forKey: LiveChecker.enabledKey)     // tests turn live check on explicitly
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        dir = url
        try? "ready".write(to: url.appendingPathComponent("status"), atomically: true, encoding: .utf8)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
    }

    func log(_ s: String) {
        guard dir != nil else { return }
        lines.append(s)
        if lines.count > 400 { lines.removeFirst(lines.count - 400) }
        try? lines.joined(separator: "\n").write(to: dir!.appendingPathComponent("events.log"), atomically: true, encoding: .utf8)
    }

    private func poll() async {
        guard !busy, let dir else { return }
        let cmdURL = dir.appendingPathComponent("cmd")
        guard let text = try? String(contentsOf: cmdURL, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: cmdURL)
        busy = true
        defer { busy = false }
        var out: [String] = []
        for step in text.split(whereSeparator: { $0 == "\n" || $0 == ";" }).map({ $0.trimmingCharacters(in: .whitespaces) }) where !step.isEmpty {
            // guard:<bundle id> — from then on, steps that touch the front app run only while that app is frontmost,
            // so a test can never act on whatever the user happens to be working in
            if step.hasPrefix("guard:") {
                requiredFront = String(step.dropFirst(6))
                // the live checker of a test instance then looks at that app and nothing else. Without this a test
                // instance followed the user into another app and accepted suggestions into what they were typing
                // (2026-11-19): it must not even read text outside the app under test.
                LiveChecker.shared.qaOnlyBundle = requiredFront
                out.append(step + " → ok"); continue
            }
            let name = String(step.split(separator: ":").first ?? "")
            if let need = requiredFront, !need.isEmpty, (["frontselect", "frontread", "hotkey", "key", "click", "type", "realclick", "realkey", "realtype"].contains(name)
                // live actions too, unless the checker is pinned to one process (then it can't reach another app)
                || (name == "live" && LiveChecker.shared.qaTargetPID == nil && ["accept", "open", "key", "next"].contains { step.dropFirst(5).hasPrefix($0) })),
               NSWorkspace.shared.frontmostApplication?.bundleIdentifier != need {
                out.append(step + " → SKIPPED: front app is \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"), not \(need)")
                continue
            }
            out.append(step + " → " + (await run(step)))
        }
        seq += 1
        writeState()
        try? out.joined(separator: "\n").write(to: dir.appendingPathComponent("log"), atomically: true, encoding: .utf8)
        try? String(seq).write(to: dir.appendingPathComponent("done"), atomically: true, encoding: .utf8)
    }

    // MARK: windows

    private var window: NSWindow? {
        let d = AppDelegate.shared
        switch targetName {
        case "panel": return PanelController.shared.panel
        case "bubble": return SelectionWatcher.shared.qaBubble
        case "onboarding": return d?.onboardingWindow
        case "settings": return d?.settingsWindow
        case "test": return d?.testWindow
        default:
            if let p = PanelController.shared.panel, p.isVisible { return p }
            return NSApp.keyWindow ?? d?.onboardingWindow ?? d?.settingsWindow
        }
    }

    private func split(_ s: String) -> (String, String) {
        guard let i = s.firstIndex(of: ":") else { return (s, "") }
        return (String(s[..<i]), String(s[s.index(after: i)...]))
    }

    private func run(_ step: String) async -> String {
        let (name, arg) = split(step)
        switch name {
        case "wait":
            try? await Task.sleep(nanoseconds: UInt64((Double(arg) ?? 1) * 1_000_000_000))
        case "target":
            targetName = arg.isEmpty ? nil : arg
        case "focus":
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        case "key": return key(arg)
        case "type":
            guard let tv = window?.firstResponder as? NSTextView else { return "no text view focused" }
            tv.insertText(arg, replacementRange: tv.selectedRange())
        case "click": return click(arg)
        case "shot": return shot(arg)
        case "open":
            let d = AppDelegate.shared
            if arg == "onboarding" { d?.openOnboarding(); targetName = "onboarding" }
            else if arg == "test" { d?.openTestWindow(); targetName = "test" }
            else if arg.hasPrefix("settings") {
                let tab = SettingsTab(rawValue: String(arg.dropFirst("settings".count).drop(while: { $0 == ":" }))) ?? .general
                d?.openSettings(tab: tab); targetName = "settings"
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        case "simulate": return simulate(arg)
        case "hotkey":
            AppDelegate.shared?.hotkey(arg == "translate" ? .translate : .fix)
            try? await Task.sleep(nanoseconds: 300_000_000)
            targetName = nil
        case "select":
            guard let tv = findTextView() else { return "no text view" }
            tv.window?.makeFirstResponder(tv)
            if arg == "all" { tv.selectAll(nil) } else {
                let p = arg.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if p.count == 2 { tv.setSelectedRange(NSRange(location: p[0], length: p[1])) }
            }
            return "selected \(tv.selectedRange()) of \((tv.string as NSString).length)"
        case "panel": return panel(arg)
        case "frontselect": return frontSelect(arg)     // real other app, through Accessibility
        case "frontread": return frontRead()
        // REAL input, posted to the system like a user's hands (needs Accessibility). Guarded like other front-app steps.
        case "realclick":        // screen point, top-left origin (same as liveMarks rectangles); "x,y" or "x,y,2" for a double click
            let p = arg.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard p.count >= 2 else { return "need x,y" }
            let pt = CGPoint(x: p[0], y: p[1]), n = p.count > 2 ? Int(p[2]) : 1
            let src = CGEventSource(stateID: .hidSystemState)
            CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cghidEventTap)
            try? await Task.sleep(nanoseconds: 80_000_000)
            for i in 1...n {
                for t in [CGEventType.leftMouseDown, .leftMouseUp] {
                    let e = CGEvent(mouseEventSource: src, mouseType: t, mouseCursorPosition: pt, mouseButton: .left)
                    e?.setIntegerValueField(.mouseEventClickState, value: Int64(i))
                    e?.post(tap: .cghidEventTap)
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            }
            return "clicked \(Int(pt.x)),\(Int(pt.y))"
        case "realkey":          // return escape tab delete right left up down space, or a letter; prefixes cmd+ ctrl+ opt+ shift+
            var flags: CGEventFlags = []
            var k = arg
            while let r = k.range(of: "+"), r.lowerBound != k.startIndex {
                switch String(k[..<r.lowerBound]) { case "cmd": flags.insert(.maskCommand); case "ctrl": flags.insert(.maskControl)
                    case "opt": flags.insert(.maskAlternate); case "shift": flags.insert(.maskShift); default: break }
                k = String(k[r.upperBound...])
            }
            let codes: [String: Int] = ["return": kVK_Return, "escape": kVK_Escape, "tab": kVK_Tab, "delete": kVK_Delete, "right": kVK_RightArrow,
                                        "left": kVK_LeftArrow, "up": kVK_UpArrow, "down": kVK_DownArrow, "pagedown": kVK_PageDown, "pageup": kVK_PageUp, "space": kVK_Space, "j": kVK_ANSI_J,
                                        "g": kVK_ANSI_G, "t": kVK_ANSI_T, "z": kVK_ANSI_Z, "a": kVK_ANSI_A, "f": kVK_ANSI_F, "end": kVK_End, "home": kVK_Home]
            guard let code = codes[k] else { return "unknown key" }
            let src = CGEventSource(stateID: .hidSystemState)
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(code), keyDown: down)
                e?.flags = flags
                e?.post(tap: .cghidEventTap)
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            return "pressed \(arg)"
        case "realtype":         // types the text as Unicode key events
            let src = CGEventSource(stateID: .hidSystemState)
            for ch in arg {
                let u = Array(String(ch).utf16)
                for down in [true, false] {
                    let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: down)
                    e?.keyboardSetUnicodeString(stringLength: u.count, unicodeString: u)
                    e?.post(tap: .cghidEventTap)
                }
                try? await Task.sleep(nanoseconds: 12_000_000)
            }
            return "typed \(arg.count) characters"
        case "axprobe": return await axProbe(arg)
        case "axtree": return axTree(arg)
        case "axwins": return axWins(arg)
        case "strprobe":           // focused text element of the front app: does AXStringForRange agree with AXValue around `arg`?
            guard let app = NSWorkspace.shared.frontmostApplication else { return "no app" }
            let appEl = AXUIElementCreateApplication(app.processIdentifier)
            var f: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f else { return "no focus" }
            let el = f as! AXUIElement
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
            let ns = (v as? String ?? "") as NSString
            var out = ["value utf16=\(ns.length) scalars=\((ns as String).unicodeScalars.count) chars=\((ns as String).count)"]
            var from = 0
            while from < ns.length {
                let r = ns.range(of: arg, options: [], range: NSRange(location: from, length: ns.length - from))
                if r.location == NSNotFound { break }
                var line = "@\(r.location):"
                for shift in [0, -1, -2, -3, -4] {
                    line += " [\(shift)]“\(WriteBack.axString(el, NSRange(location: r.location + shift, length: r.length)) ?? "nil")”"
                }
                out.append(line); from = NSMaxRange(r)
            }
            return "\n" + out.joined(separator: "\n")
        case "wordax": return wordAX()
        case "download":           // start a real built-in model download (first-use test); "downloadstate:<id>" reports
            Task { await BuiltInModels.shared.download(arg) }
            return "started"
        case "downloadstate": return String(describing: BuiltInModels.shared.state(arg))
        case "usebuiltin":         // what the panel's first-use button does once the model is there
            PanelController.shared.model?.useBuiltInModel(arg); return "ok"
        case "narrationtest":      // the pure part of the Word "Field" handling, on fixed cases
            let doc = "Plants such as Arabidopsis thaliana grows fast in the lab (Smith 2020) and H2O is used.\rIn Springfield the Field Museum were closed (Lee 2021).\r"
            var lines: [String] = []
            for ax in ["Plants such as Arabidopsis thaliana grows fast in the lab Field (Smith 2020) and H2O is used.",
                       "In Springfield the Field Museum were closed Field (Lee 2021)."] {
                let hidden = LiveChecker.narration(in: ax, document: doc)
                let sent = LiveChecker.removing(hidden, from: ax)
                // pretend the model fixed the verb
                let fixed = sent.replacingOccurrences(of: "grows fast", with: "grow fast").replacingOccurrences(of: "were closed", with: "was closed")
                let back = LiveChecker.mapBack(WordDiff.changes(from: sent, to: fixed), hidden: hidden)
                let ns = ax as NSString
                lines.append("hidden=\(hidden.map { "\($0.location)+\($0.length)" }) sent=“\(sent)” changes=" + back.map { "\($0.removed)→\($0.inserted) at “\(ns.substring(with: $0.range))”" }.joined(separator: ", "))
            }
            return "\n" + lines.joined(separator: "\n")
        case "bubble": SelectionWatcher.shared.qaShow(); return "shown"
        case "bubblekeys":     // what a keyboard selection in the front app would bring up, and whether it takes keys
            SelectionWatcher.shared.qaKeyboardSelection()
            return "keyboardMode=\(SelectionWatcher.shared.keyboardMode) visible=\(SelectionWatcher.shared.qaBubble != nil)"
        case "bubblekey":
            let codes = ["return": kVK_Return, "tab": kVK_Tab, "escape": kVK_Escape, "a": kVK_ANSI_A]
            let used = SelectionWatcher.shared.handleKey(codes[arg] ?? kVK_ANSI_A, modifiers: [])
            return "used=\(used) visible=\(SelectionWatcher.shared.qaBubble != nil) panel=\(PanelController.shared.isOpen)"
        case "wordrects": return wordRects(arg)
        case "axdoc": return await axDoc(arg)
        case "live":
            let lc = LiveChecker.shared
            if arg == "on" { lc.enabled = true; return "on" }
            if arg == "off" { lc.enabled = false; return "off" }
            if arg == "z" { return lc.zOrder() }
            if arg == "next" { lc.reviewNext(); return "card: " + (lc.activeMark.map { "\($0.removed) → \($0.inserted)" } ?? "none") }
            if arg.hasPrefix("open="), let i = Int(arg.dropFirst(5)), lc.marks.indices.contains(i) { lc.open(lc.marks[i]); return "opened \(i)" }
            if arg.hasPrefix("key=") {      // the same handler the event tap calls
                let codes = ["return": kVK_Return, "escape": kVK_Escape, "tab": kVK_Tab, "a": kVK_ANSI_A, "space": kVK_Space,
                             "delete": kVK_Delete, "right": kVK_RightArrow]
                let used = lc.handleKey(codes[String(arg.dropFirst(4))] ?? kVK_ANSI_A, modifiers: [])
                return "used=\(used) card: " + (lc.activeMark.map { "\($0.removed) → \($0.inserted)" } ?? "none")
            }
            if arg.hasPrefix("app=") {      // pin a running app by bundle id, even in the background
                let b = String(arg.dropFirst(4))
                lc.qaTargetPID = NSRunningApplication.runningApplications(withBundleIdentifier: b).first?.processIdentifier
                return "pinned \(b) pid \(lc.qaTargetPID ?? 0)"
            }
            if arg.hasPrefix("accept="), let i = Int(arg.dropFirst(7)), lc.marks.indices.contains(i) { lc.accept(lc.marks[i]); return "accepting \(i)" }
            if arg.hasPrefix("acceptat=") {      // by position, not by index: the list may have changed since the dump
                let p = arg.dropFirst(9).split(separator: ",").compactMap { Int($0) }
                guard p.count == 2, let m = lc.marks.first(where: { $0.range.location == p[0] && $0.range.length == p[1] }) else { return "NOMARK" }
                return lc.accept(m) ? "accepting" : "BUSY"
            }
            return lc.status + " | " + lc.dump().joined(separator: " ; ")
        case "set":
            let kv = arg.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { return "bad" }
            if kv[1] == "true" || kv[1] == "false" { Store.defaults.set(kv[1] == "true", forKey: kv[0]) }
            else if kv[1] == "nil" { Store.defaults.removeObject(forKey: kv[0]) }
            else if ["gb_languages", "gb_protected", "gb_local_only", "gb_disabled_apps"].contains(kv[0]) {
                Store.defaults.set(kv[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, forKey: kv[0])
            }
            else { Store.defaults.set(kv[1], forKey: kv[0]) }
        case "engine": return engine(arg)
        case "dump": writeState()
        case "quit": NSApp.terminate(nil)
        default: return "unknown command"
        }
        return "ok"
    }

    private func findTextView() -> NSTextView? {
        if let tv = window?.firstResponder as? NSTextView { return tv }
        func walk(_ v: NSView) -> NSTextView? {
            if let t = v as? NSTextView { return t }
            for s in v.subviews { if let t = walk(s) { return t } }
            return nil
        }
        return window?.contentView.flatMap(walk)
    }

    // MARK: the real front app (needs Accessibility for GrammarBuddy)

    private func frontElement() -> (NSRunningApplication, AXUIElement)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f else { return nil }
        return (app, f as! AXUIElement)
    }

    /// Read-only: what does an app expose through Accessibility, before and after asking it to turn its tree on?
    /// (AXManualAccessibility for Electron, AXEnhancedUserInterface for Chromium.) The switch is set back afterwards.
    private func axProbe(_ bundle: String) async -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return "\(bundle): not running" }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 1.0)
        func describe() -> String {
            var f: CFTypeRef?
            let st = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f)
            guard st == .success, let f else { return "no focused element (status \(st.rawValue))" }
            let el = f as! AXUIElement
            AXUIElementSetMessagingTimeout(el, 1.0)
            let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? "?"
            var v: CFTypeRef?
            let vs = AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
            let len = (v as? String).map { ($0 as NSString).length }
            var names: CFArray?
            AXUIElementCopyParameterizedAttributeNames(el, &names)
            let pn = (names as? [String]) ?? []
            var attrs: CFArray?
            AXUIElementCopyAttributeNames(el, &attrs)
            let an = (attrs as? [String]) ?? []
            var settable: DarwinBoolean = false
            AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable)
            var bounds = "n/a"
            if let len, len > 0 {
                var cf = CFRange(location: 0, length: min(5, len))
                var out: CFTypeRef?
                if let ax = AXValueCreate(.cfRange, &cf),
                   AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, ax, &out) == .success, let out {
                    var r = CGRect.zero; AXValueGetValue(out as! AXValue, .cgRect, &r)
                    bounds = "\(Int(r.width))×\(Int(r.height))"
                } else { bounds = "failed" }
            }
            return "role=\(role) value=\(len.map(String.init) ?? "none(\(vs.rawValue))") settable=\(settable.boolValue) "
                + "selRange=\(an.contains(kAXSelectedTextRangeAttribute as String)) boundsForRange=\(pn.contains(kAXBoundsForRangeParameterizedAttribute as String))(\(bounds)) "
                + "textMarkers=\(pn.contains("AXBoundsForTextMarkerRange")) stringForRange=\(pn.contains(kAXStringForRangeParameterizedAttribute as String))"
                + " selMarker=\(an.contains("AXSelectedTextMarkerRange")) markerForIndex=\(pn.contains("AXTextMarkerForIndex")) params=\(pn.count) attrs=\(an.count)"
                + "\n      PARAMS: " + pn.filter { $0.contains("Marker") || $0.contains("Range") || $0.contains("Index") }.joined(separator: " ")
                + "\n      ATTRS: " + an.filter { $0.contains("Marker") || $0.contains("Range") || $0.contains("Text") }.joined(separator: " ")
        }
        let before = describe()
        let manual = AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        let enhanced = AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        let after = describe()
        AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        return "\(bundle)\n    before: \(before)\n    switch: manual=\(manual.rawValue) enhanced=\(enhanced.rawValue)\n    after:  \(after)"
    }

    /// Read-only: roles in the focused window of an app, with the text-related attributes of each text-like element.
    /// Every window of an app (role, subrole, title, frame) with the labelled elements inside the small ones.
    /// Used to identify a host's own popups (Word's Editor card, autocorrect button).
    private func axWins(_ bundle: String) -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return "not running" }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 1.0)
        var w: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &w) == .success, let wins = w as? [AXUIElement] else { return "no windows" }
        var out: [String] = []
        func str(_ el: AXUIElement, _ a: String) -> String { SelectionReader.stringAttr(el, a) ?? "" }
        func frame(_ el: AXUIElement) -> CGRect {
            var p: CFTypeRef?, s: CFTypeRef?
            var pt = CGPoint.zero, sz = CGSize.zero
            if AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success, let p { AXValueGetValue(p as! AXValue, .cgPoint, &pt) }
            if AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success, let s { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
            return CGRect(origin: pt, size: sz)
        }
        for win in wins {
            let f = frame(win)
            out.append("WINDOW \(str(win, kAXRoleAttribute))/\(str(win, kAXSubroleAttribute)) title=\"\(str(win, kAXTitleAttribute))\" \(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height))")
            guard f.width < 700 else { continue }
            var count = 0
            func walk(_ el: AXUIElement, _ depth: Int) {
                guard depth <= 8, count < 80 else { return }
                count += 1
                let label = [str(el, kAXTitleAttribute), str(el, kAXDescriptionAttribute), str(el, kAXValueAttribute), str(el, kAXHelpAttribute)].filter { !$0.isEmpty }.joined(separator: " | ")
                out.append(String(repeating: "  ", count: depth + 1) + str(el, kAXRoleAttribute) + (label.isEmpty ? "" : " “\(label.prefix(90))”"))
                var kids: CFTypeRef?
                guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids) == .success, let arr = kids as? [AXUIElement] else { return }
                for k in arr.prefix(20) { walk(k, depth + 1) }
            }
            walk(win, 0)
        }
        return out.joined(separator: "\n")
    }

    /// Every text area inside Word's document layout, with what Word says about it and about its parents.
    private func wordAX() -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: AppProfiles.word).first else { return "not running" }
        var out: [String] = []
        func str(_ el: AXUIElement, _ a: String) -> String { SelectionReader.stringAttr(el, a) ?? "" }
        func parent(_ el: AXUIElement) -> AXUIElement? {
            var p: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &p) == .success, let p else { return nil }
            return (p as! AXUIElement)
        }
        for pg in WordAX.pages(pid: app.processIdentifier, all: true) {
            var chain: [String] = []
            var cur = pg.element
            for _ in 0..<4 {
                guard let p = parent(cur) else { break }
                let kidsN: Int = { var k: CFTypeRef?; AXUIElementCopyAttributeValue(p, kAXChildrenAttribute as CFString, &k); return (k as? [AXUIElement])?.count ?? 0 }()
                chain.append("\(str(p, kAXRoleAttribute))[\(kidsN)]“\(str(p, kAXDescriptionAttribute))”")
                cur = p
            }
            var sr: CFTypeRef?; var cf = CFRange(location: -1, length: -1)
            if AXUIElementCopyAttributeValue(pg.element, "AXSharedCharacterRange" as CFString, &sr) == .success, let sr, CFGetTypeID(sr) == AXValueGetTypeID() { AXValueGetValue(sr as! AXValue, .cfRange, &cf) }
            let f = pg.frame
            out.append("AREA body=\(pg.isBody) focused=\(pg.focused) desc=“\(str(pg.element, kAXDescriptionAttribute))” help=“\(str(pg.element, kAXHelpAttribute))” shared=\(cf.location)+\(cf.length) len=\((pg.text as NSString).length) frame=\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height)) parents=\(chain.joined(separator: " < "))")
            out.append("   " + String(reflecting: pg.text))
        }
        return out.joined(separator: "\n")
    }

    /// For each body page of Word: where it is, and for every occurrence of `needle` in its text what Word returns
    /// for that range (the string and the rectangle). Shows whether indices in AXValue and in AXBoundsForRange agree.
    private func wordRects(_ needle: String) -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: AppProfiles.word).first else { return "not running" }
        var out: [String] = ["view=\(WordAX.lastViewFrame)"]
        for pg in WordAX.pages(pid: app.processIdentifier) {
            let ns = pg.text as NSString
            var vis: CFTypeRef?; var vr = CFRange()
            if AXUIElementCopyAttributeValue(pg.element, kAXVisibleCharacterRangeAttribute as CFString, &vis) == .success, let vis { AXValueGetValue(vis as! AXValue, .cfRange, &vr) }
            var selv: CFTypeRef?; var sel = CFRange(location: -1, length: -1)
            if AXUIElementCopyAttributeValue(pg.element, kAXSelectedTextRangeAttribute as CFString, &selv) == .success, let selv { AXValueGetValue(selv as! AXValue, .cfRange, &sel) }
            out.append("  selectedRange=\(sel.location)+\(sel.length)")
            out.append("PAGE offset=\(pg.offset) len=\(ns.length) frame=\(pg.frame) visibleArea=\(Int(pg.visibleArea)) focused=\(pg.focused) visibleRange=\(vr.location)+\(vr.length) starts=“\(ns.substring(to: min(30, ns.length)))”")
            var from = 0
            while from < ns.length {
                let r = ns.range(of: needle, options: [], range: NSRange(location: from, length: ns.length - from))
                if r.location == NSNotFound { break }
                var cf = CFRange(location: r.location, length: r.length)
                let v = AXValueCreate(.cfRange, &cf)!
                var sv: CFTypeRef?, bv: CFTypeRef?
                AXUIElementCopyParameterizedAttributeValue(pg.element, kAXStringForRangeParameterizedAttribute as CFString, v, &sv)
                AXUIElementCopyParameterizedAttributeValue(pg.element, kAXBoundsForRangeParameterizedAttribute as CFString, v, &bv)
                var rect = CGRect.zero
                if let bv { AXValueGetValue(bv as! AXValue, .cgRect, &rect) }
                var cf2 = CFRange(location: r.location + pg.offset, length: r.length)
                let v2 = AXValueCreate(.cfRange, &cf2)!
                var sv2: CFTypeRef?, bv2: CFTypeRef?
                AXUIElementCopyParameterizedAttributeValue(pg.element, kAXStringForRangeParameterizedAttribute as CFString, v2, &sv2)
                AXUIElementCopyParameterizedAttributeValue(pg.element, kAXBoundsForRangeParameterizedAttribute as CFString, v2, &bv2)
                var rect2 = CGRect.zero
                if let bv2 { AXValueGetValue(bv2 as! AXValue, .cgRect, &rect2) }
                out.append("   @\(r.location) local: “\(sv as? String ?? "nil")” \(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))×\(Int(rect.height))   +offset: “\(sv2 as? String ?? "nil")” \(Int(rect2.minX)),\(Int(rect2.minY)) \(Int(rect2.width))×\(Int(rect2.height))")
                from = NSMaxRange(r)
            }
        }
        return out.joined(separator: "\n")
    }

    private func axTree(_ bundle: String) -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return "not running" }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 1.0)
        var out: [String] = []
        func attrNames(_ el: AXUIElement) -> ([String], [String]) {
            var a: CFArray?, p: CFArray?
            AXUIElementCopyAttributeNames(el, &a); AXUIElementCopyParameterizedAttributeNames(el, &p)
            return ((a as? [String]) ?? [], (p as? [String]) ?? [])
        }
        func line(_ el: AXUIElement, _ depth: Int, _ tag: String) {
            let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? "?"
            let sub = SelectionReader.stringAttr(el, kAXSubroleAttribute) ?? ""
            let (an, pn) = attrNames(el)
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
            let len = (v as? String).map { ($0 as NSString).length }
            var s = String(repeating: "  ", count: depth) + tag + role + (sub.isEmpty ? "" : "/" + sub)
            if let len { s += " value=\(len)" }
            let texty = an.filter { $0.contains("Text") || $0.contains("Range") || $0.contains("Marker") || $0.contains("Insertion") }
            if !texty.isEmpty || !pn.isEmpty { s += " ATTR[" + texty.joined(separator: ",") + "] PARAM[" + pn.joined(separator: ",") + "]" }
            out.append(s)
        }
        var f: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f {
            line(f as! AXUIElement, 0, "FOCUSED: ")
            // parents of the focused element
            var cur = f as! AXUIElement
            for i in 1...6 {
                var p: CFTypeRef?
                guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &p) == .success, let p else { break }
                cur = p as! AXUIElement
                line(cur, 0, "parent\(i): ")
            }
        } else { out.append("FOCUSED: none") }
        var w: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &w) == .success, let w {
            var count = 0
            func walk(_ el: AXUIElement, _ depth: Int) {
                guard depth <= 7, count < 120 else { return }
                count += 1
                line(el, depth, "")
                var kids: CFTypeRef?
                guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids) == .success, let arr = kids as? [AXUIElement] else { return }
                for k in arr.prefix(12) { walk(k, depth + 1) }
            }
            walk(w as! AXUIElement, 0)
        }
        return "\n" + out.joined(separator: "\n")
    }

    /// Read-only: the document area (first AXLayoutArea / AXTextArea / AXWebArea in the focused window), all its
    /// attribute names, and its descendants; before and after AXEnhancedUserInterface / AXManualAccessibility.
    private func axDoc(_ bundle: String) async -> String {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { return "not running" }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 1.5)
        func kids(_ el: AXUIElement) -> [AXUIElement] {
            var k: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &k) == .success else { return [] }
            return (k as? [AXUIElement]) ?? []
        }
        func find(_ el: AXUIElement, _ depth: Int) -> AXUIElement? {
            let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? ""
            if ["AXLayoutArea", "AXTextArea", "AXWebArea"].contains(role) { return el }
            guard depth < 9 else { return nil }
            for k in kids(el).prefix(20) { if let f = find(k, depth + 1) { return f } }
            return nil
        }
        func dump() -> String {
            var w: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &w) == .success, let w,
                  let doc = find(w as! AXUIElement, 0) else { return "  no document area found" }
            var lines: [String] = []
            var count = 0
            func walk(_ el: AXUIElement, _ depth: Int) {
                guard depth <= 6, count < 60 else { return }
                count += 1
                var a: CFArray?, p: CFArray?
                AXUIElementCopyAttributeNames(el, &a); AXUIElementCopyParameterizedAttributeNames(el, &p)
                let an = (a as? [String]) ?? [], pn = ((p as? [String]) ?? []).filter { $0 != "AXReplaceRangeWithText" }
                let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? "?"
                var v: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
                let val = v as? String
                var nchars: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXNumberOfCharactersAttribute as CFString, &nchars)
                let ks = kids(el)
                var s = String(repeating: "  ", count: depth + 1) + role + " kids=\(ks.count)"
                if let val { s += " value(\((val as NSString).length))=\"\(val.prefix(30))\"" }
                if let n = nchars { s += " nchars=\(n)" }
                if depth == 0 || !pn.isEmpty { s += "\n" + String(repeating: "  ", count: depth + 2) + "attrs: " + an.joined(separator: ",") + (pn.isEmpty ? "" : "\n" + String(repeating: "  ", count: depth + 2) + "params: " + pn.joined(separator: ",")) }
                lines.append(s)
                for k in ks.prefix(8) { walk(k, depth + 1) }
            }
            walk(doc, 0)
            // other ways in: visible children, hit-testing the middle of the area, the focused element
            var vis: CFTypeRef?
            AXUIElementCopyAttributeValue(doc, kAXVisibleChildrenAttribute as CFString, &vis)
            lines.append("    visibleChildren=\((vis as? [AXUIElement])?.count ?? -1)")
            var pv: CFTypeRef?, sv: CFTypeRef?
            AXUIElementCopyAttributeValue(doc, kAXPositionAttribute as CFString, &pv)
            AXUIElementCopyAttributeValue(doc, kAXSizeAttribute as CFString, &sv)
            var pt = CGPoint.zero, sz = CGSize.zero
            if let pv { AXValueGetValue(pv as! AXValue, .cgPoint, &pt) }
            if let sv { AXValueGetValue(sv as! AXValue, .cgSize, &sz) }
            lines.append("    frame=\(Int(pt.x)),\(Int(pt.y)) \(Int(sz.width))×\(Int(sz.height))")
            func describe(_ el: AXUIElement, _ tag: String) {
                var a: CFArray?, p: CFArray?
                AXUIElementCopyAttributeNames(el, &a); AXUIElementCopyParameterizedAttributeNames(el, &p)
                let pn = ((p as? [String]) ?? []).filter { $0 != "AXReplaceRangeWithText" }
                var v: CFTypeRef?
                AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
                let val = v as? String
                lines.append("    \(tag): \(SelectionReader.stringAttr(el, kAXRoleAttribute) ?? "?") kids=\(kids(el).count)"
                             + (val.map { " value(\(($0 as NSString).length))=\"\($0.prefix(40))\"" } ?? "")
                             + "\n        attrs: " + ((a as? [String]) ?? []).joined(separator: ",")
                             + "\n        params: " + pn.joined(separator: ","))
            }
            for (dx, dy) in [(0.5, 0.25), (0.5, 0.5)] {
                var hit: AXUIElement?
                if AXUIElementCopyElementAtPosition(appEl, Float(pt.x + sz.width * dx), Float(pt.y + sz.height * dy), &hit) == .success, let hit {
                    describe(hit, "hit(\(dx),\(dy))")
                }
            }
            var f: CFTypeRef?
            if AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f { describe(f as! AXUIElement, "focused") }
            return lines.joined(separator: "\n")
        }
        let before = dump()
        let e1 = AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        let e2 = AXUIElementSetAttributeValue(appEl, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var report = "\nBEFORE:\n\(before)\nSWITCH enhanced=\(e1.rawValue) manual=\(e2.rawValue)"
        for wait in [2, 4, 6] {
            try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000_000)
            var flag: CFTypeRef?
            AXUIElementCopyAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, &flag)
            let d = dump()
            report += "\nAFTER +\(wait)s (flag reads \(flag.map { "\($0)" } ?? "nil")):\n\(d)"
            if d.contains("AXTextArea") { break }
        }
        return report   // the switch is left on: Word builds its document tree only while it is set
    }

    private func frontSelect(_ arg: String) -> String {
        guard let (app, el) = frontElement() else { return "no focused element in front app" }
        var v: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
        let len = ((v as? String) ?? "" as String).utf16.count
        let p = arg.split(separator: ",").compactMap { Int($0) }
        var cf = arg == "all" ? CFRange(location: 0, length: len) : CFRange(location: p.first ?? 0, length: p.count > 1 ? p[1] : 0)
        let ax = AXValueCreate(.cfRange, &cf)!
        let st = AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, ax)
        return "\(app.bundleIdentifier ?? "?"): set range \(cf.location),\(cf.length) of \(len) → \(st.rawValue)"
    }

    private func frontRead() -> String {
        guard let (app, el) = frontElement() else { return "no focused element" }
        var v: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v)
        let text = (v as? String) ?? "<no value>"
        var sel: CFTypeRef?, role: CFTypeRef?, r: CFTypeRef?
        let st = AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &sel)
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &r)
        var cf = CFRange(); if let r { AXValueGetValue(r as! AXValue, .cfRange, &cf) }
        log("frontread \(app.bundleIdentifier ?? ""): " + text)
        return "role=\(role as? String ?? "?") selStatus=\(st.rawValue) selected=[\(sel as? String ?? "nil")] range=\(cf.location),\(cf.length) value=[\(text)]"
    }

    // MARK: events

    private func key(_ spec: String) -> String {
        guard let w = window else { return "no window" }
        var flags: NSEvent.ModifierFlags = []
        var k = spec
        while let r = k.range(of: "+"), r.lowerBound != k.startIndex {
            let m = String(k[..<r.lowerBound])
            switch m { case "cmd": flags.insert(.command); case "opt": flags.insert(.option); case "shift": flags.insert(.shift); case "ctrl": flags.insert(.control); default: break }
            k = String(k[r.upperBound...])
        }
        let map: [String: (UInt16, String)] = ["return": (36, "\r"), "escape": (53, "\u{1b}"), "tab": (48, "\t"), "space": (49, " "),
                                               "up": (126, "\u{F700}"), "down": (125, "\u{F701}"), "left": (123, "\u{F702}"), "right": (124, "\u{F703}"),
                                               "delete": (51, "\u{7f}")]
        let letters: [Character: UInt16] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
                                            "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26,
                                            "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46]
        let (code, chars): (UInt16, String)
        if let m = map[k] { (code, chars) = m } else if let c = k.first, k.count == 1 { (code, chars) = (letters[c] ?? 0, k) } else { return "unknown key" }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                        windowNumber: w.windowNumber, context: nil, characters: chars, charactersIgnoringModifiers: chars,
                                        isARepeat: false, keyCode: code) {
                w.sendEvent(e)
            }
        }
        return "ok"
    }

    private func click(_ arg: String) -> String {
        guard let w = window else { return "no window" }
        let p = arg.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard p.count == 2 else { return "bad coords" }
        let frameH = w.frame.height
        let loc = NSPoint(x: p[0], y: frameH - p[1])
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: loc, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: w.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                w.sendEvent(e)
            }
        }
        return "ok"
    }

    private func shot(_ arg: String) -> String {
        guard let dir else { return "no dir" }
        let all = arg.hasSuffix("@all")
        let name = all ? String(arg.dropLast(4)) : arg
        let wins: [NSWindow] = all ? NSApp.windows.filter { $0.isVisible && $0.frame.width > 120 } : [window].compactMap { $0 }
        guard !wins.isEmpty else { return "no window" }
        var saved: [String] = []
        for (i, w) in wins.enumerated() {
            guard let v = w.contentView?.superview ?? w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
            v.cacheDisplay(in: v.bounds, to: rep)
            let file = all ? "\(name)-\(i).png" : "\(name).png"
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(file))
            saved.append(file + " (\(Int(w.frame.width))×\(Int(w.frame.height)) \(w.title.isEmpty ? String(describing: type(of: w)) : w.title))")
        }
        return saved.joined(separator: ", ")
    }

    // MARK: simulated captures (writes are logged, not performed)

    private func simulate(_ arg: String) -> String {
        var j: [String: Any] = [:]
        let presets: [String: [String: Any]] = [
            "textedit": ["app": "com.apple.TextEdit", "name": "TextEdit", "via": "accessibility", "edit": "editable", "rich": "plain", "range": true,
                         "text": "Their are three reason why the flc-3 mutant flower earlier then Col-0 under long days (16 h light / 8 h dark), as previously reported [12, 15]."],
            "slack": ["app": "com.tinyspeck.slackmacgap", "name": "Slack", "via": "clipboard", "edit": "unknown", "rich": "plain",
                      "text": "hey team, i has finished the deck for tomorow, can you have a look before friday? its in the shared drive"],
            "gmail-chrome": ["app": "com.google.Chrome", "name": "Google Chrome", "via": "clipboard", "edit": "unknown", "rich": "rich", "formatting": 1,
                             "text": "Hi Anna, thanks for you're quick reply. I have attach the contract draft, please let me know if their are any problem."],
            "word": ["app": "com.microsoft.Word", "name": "Microsoft Word", "via": "word", "edit": "editable", "rich": "rich",
                     "text": "Expression of FLC were reduced by 0.5× in Arabidopsis thaliana seedlings treated at 4 °C for 30 d (P < 0.05; Smith et al., 2020), which suggest that the vernalisation response is conserved."],
            "word-translate": ["app": "com.microsoft.Word", "name": "Microsoft Word", "via": "word", "edit": "editable", "rich": "rich", "op": "translate",
                               "text": "我们的结果表明，FLC 的表达在春化处理 30 天后下降了约一半 [12]。"],
            "terminal": ["app": "com.apple.Terminal", "name": "Terminal", "via": "accessibility", "edit": "readOnly", "rich": "plain",
                         "text": "git commit -m \"fix teh bug in the parser wich crash on empty input\""],
            "pages": ["app": "com.apple.iWork.Pages", "name": "Pages", "via": "accessibility", "edit": "editable", "rich": "rich", "range": true, "op": "translate",
                      "text": "El Ayuntamiento aprobó ayer el nuevo presupuesto, que asciende a 1.400 millones de euros.\n\n«No vamos a subir los impuestos», dijo la alcaldesa."],
            "manual": ["manual": true],
            "noax": ["noax": true],
        ]
        if let p = presets[arg] { j = p }
        else if let d = arg.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { j = o }
        else if let base = presets[String(arg.split(separator: "+").first ?? "")] {
            // preset+op, e.g. slack+polish
            j = base; j["op"] = String(arg.split(separator: "+").last ?? "fix")
        } else { return "unknown preset" }
        let op = TextOperation(rawValue: j["op"] as? String ?? "fix") ?? .fix
        if j["manual"] as? Bool == true {
            PanelController.shared.show(outcome: nil, failure: .noSelection, operation: op, app: nil, qa: true)
            targetName = "panel"; return "ok"
        }
        if j["noax"] as? Bool == true {
            PanelController.shared.show(outcome: nil, failure: .noAccessibilityPermission, operation: op, app: nil, qa: true)
            targetName = "panel"; return "ok"
        }
        let text = j["text"] as? String ?? ""
        let via = CaptureSource(rawValue: j["via"] as? String ?? "accessibility") ?? .accessibility
        let app = TargetApp(bundleID: j["app"] as? String ?? "com.apple.TextEdit", name: j["name"] as? String ?? "TextEdit", pid: 0)
        var cap = Capture(raw: text, via: via, editability: Editability(rawValue: j["edit"] as? String ?? "unknown") ?? .unknown,
                          richText: RichText(rawValue: j["rich"] as? String ?? "unknown") ?? .unknown,
                          range: (j["range"] as? Bool == true) ? NSRange(location: 0, length: (text as NSString).length) : nil, app: app)
        cap.formattingCount = j["formatting"] as? Int
        if via == .clipboard && AppProfiles.profile(for: app.bundleID).emptyCopyCopiesLine { cap.notes.append(.maybeWholeLine) }
        let h = WriteHandle(pid: 0, element: nil, wordStart: via == .word ? 100 : nil, wordEnd: via == .word ? 100 + (text as NSString).length : nil)
        let fake = FakeApp(name: app.name)
        PanelController.shared.show(outcome: ReadOutcome(capture: cap, handle: h, bounds: nil, windowFrame: nil), failure: nil, operation: op, app: nil, qa: true)
        PanelController.shared.model?.appName = fake.name
        // insert-below is possible for Word and for AX captures with a numeric range
        targetName = "panel"
        return "ok"
    }

    struct FakeApp { var name: String }

    private func panel(_ arg: String) -> String {
        guard let m = PanelController.shared.model else { return "no panel" }
        let kv = arg.split(separator: "=", maxSplits: 1).map(String.init)
        let a = kv.first ?? "", v = kv.count > 1 ? kv[1] : ""
        switch a {
        case "toggle": m.toggle(Int(v) ?? 0)
        case "tone": if let t = Tone(rawValue: v) { m.chooseTone(t) }
        case "target": m.setTarget(v, remember: false)
        case "source": m.setSource(v)
        case "engine": m.engineOverride = v; m.run()
        case "op": if let o = TextOperation(rawValue: v) { m.switchOperation(o) }
        case "allow": m.allowAPI(always: v != "once")
        case "refuse": m.refuseAPI()
        case "first": m.processFirstParagraphs(Int(v) ?? 1)
        case "diff": break        // the view switch is gone
        case "retry": m.run()
        case "polishTranslate": m.translateAndPolish()
        case "swap": m.swapLanguages()
        case "aiTranslate": if m.useSystemTranslation { m.toggleTranslationEngine() }
        case "sysTranslate": if !m.useSystemTranslation { m.toggleTranslationEngine() }
        case "undoWord": Task { await m.undoWord() }
        case "copyList": m.copyChangeList()
        case "leave": m.leftPanel = true
        default: return "unknown panel action"
        }
        return "ok"
    }

    private func engine(_ arg: String) -> String {
        let s = AppState.shared
        let kv = arg.split(separator: "=", maxSplits: 1).map(String.init)
        switch kv.first {
        case "clear": s.engines = []; s.activeEngineID = nil
        case "local":
            var es = s.engines.filter { $0.kind == .api }
            es.insert(EngineConfig(id: "local", kind: .lmstudio, name: "LM Studio", baseURL: "http://localhost:1234", model: kv.count > 1 ? kv[1] : "qwen/qwen3-8b"), at: 0)
            s.engines = es
            if s.activeEngineID == nil { s.activeEngineID = "local" }
        case "api":
            let p = (kv.count > 1 ? kv[1] : "").split(separator: "|").map(String.init)
            guard p.count >= 2 else { return "need base|model|key" }
            Keychain.set(p.count > 2 ? p[2] : "", account: "api-qa")
            var es = s.engines.filter { $0.kind != .api }
            es.append(EngineConfig(id: "api", kind: .api, name: URL(string: p[0])?.host ?? "API", baseURL: p[0], model: p[1], keychainAccount: "api-qa"))
            s.engines = es
            if s.activeEngineID == nil { s.activeEngineID = "api" }
            if p.count > 3 && p[3] == "local" { Store.defaults.set(true, forKey: "gb_qa_api_via_local") }
        case "active": s.activeEngineID = kv.count > 1 ? kv[1] : nil
        case "builtin":
            var es = s.engines.filter { $0.id != "builtin" }
            es.insert(EngineConfig(id: "builtin", kind: .builtin, name: "Built-in", baseURL: "builtin:mlx",
                                   model: kv.count > 1 ? kv[1] : "mlx-community/Qwen3-4B-Instruct-2507-4bit"), at: 0)
            s.engines = es
            s.activeEngineID = "builtin"
        default: return "unknown"
        }
        return "engines: " + s.engines.map { "\($0.id)=\($0.name)/\($0.model)" }.joined(separator: ", ")
    }

    // MARK: state dump for agents

    private func writeState() {
        guard let dir else { return }
        var o: [String: Any] = [:]
        let pc = PanelController.shared
        o["panelOpen"] = pc.isOpen
        o["panelSize"] = pc.panel.map { "\(Int($0.frame.width))×\(Int($0.frame.height))" } ?? ""
        o["panelIsKey"] = pc.panel?.isKeyWindow ?? false
        o["appIsActive"] = NSApp.isActive
        o["keyWindow"] = NSApp.keyWindow?.title ?? (NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "none")
        o["windows"] = NSApp.windows.filter(\.isVisible).map { "\($0.title.isEmpty ? String(describing: type(of: $0)) : $0.title) \(Int($0.frame.width))×\(Int($0.frame.height))" }
        o["lastToast"] = Toast.last ?? ""
        o["liveMarks"] = LiveChecker.shared.dump()
        o["liveMarksDetail"] = LiveChecker.shared.dumpDetail()
        o["liveStatus"] = LiveChecker.shared.status
        o["liveValue"] = LiveChecker.shared.lastValue
        o["liveCard"] = LiveChecker.shared.activeMark.map { "\($0.removed) → \($0.inserted)" } ?? ""
        o["wordPopupsDismissed"] = LiveChecker.shared.wordPopupsDismissed
        o["wordDropped"] = LiveChecker.shared.wordDropped
        o["liveRejected"] = LiveChecker.shared.rejected
        o["engines"] = AppState.shared.engines.map { "\($0.id): \($0.name) \($0.model) \($0.baseURL)" }
        o["activeEngine"] = AppState.shared.activeEngine?.id ?? ""
        o["myLanguages"] = AppState.shared.myLanguages
        o["onboardingDone"] = AppState.shared.onboardingDone
        o["accessibilityTrusted"] = SelectionReader.hasAccessibility
        if let m = pc.model {
            o["operation"] = m.operation.rawValue
            o["phase"] = String(describing: m.phase)
            o["badge"] = m.badge.text
            o["badgeLeavesMac"] = m.badge.leaves
            o["original"] = m.capture?.text ?? ""
            o["output"] = m.output
            o["finalText"] = m.finalText
            o["changes"] = m.changes.map { "\($0.id): \($0.label) accepted=\($0.accepted) \($0.flags.map(\.rawValue).joined(separator: ","))" }
            o["checksFailed"] = m.checks.failed
            o["checksSummary"] = m.checks.summary
            o["numberMismatch"] = m.checks.numberMismatch
            o["note"] = m.note?.text ?? ""
            o["source"] = m.sourceLang; o["target"] = m.targetLang
            o["thinkingSeconds"] = m.thinkingSeconds
            o["finish"] = m.finish.rawValue
            o["leftPanel"] = m.leftPanel
            o["qaLog"] = m.qaLog
            if let r = m.recommendation {
                o["enter"] = r.enter.rawValue
                o["enterReason"] = r.enterReason ?? ""
                switch r.putBack {
                case .unavailable(let why): o["cmdEnter"] = "unavailable: " + why
                case .available(let cs): o["cmdEnter"] = cs.isEmpty ? "available" : "available, confirm: " + (r.confirmText ?? "")
                }
                o["insertBelow"] = r.insertBelow
            }
        }
        if let d = try? JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: dir.appendingPathComponent("state.json"))
        }
    }
}
#else
@MainActor
final class QAHarness {
    static let shared = QAHarness()
    var suppressOnboarding: Bool { false }
    func startIfRequested() {}
    func log(_ s: String) {}
}
#endif
