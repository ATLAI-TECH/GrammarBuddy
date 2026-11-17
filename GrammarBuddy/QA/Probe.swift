// Probe.swift  (DEBUG only)
// M0 read/write probe (design §11 M0 checklist): menu item → 3 s later, probe the front app and append one JSON
// line to ~/Library/Logs/GrammarBuddy/probe.jsonl. Needs the Accessibility permission for GrammarBuddy.
// Writes are only tried in TextEdit (safe to test); every other app is read-only probing.

#if DEBUG
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import GrammarBuddyKit

@MainActor
enum Probe {
    static var logURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GrammarBuddy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("probe.jsonl")
    }

    static func runSoon() {
        Toast.show(L.t("3 秒后探测前台 App：请切到要测的 App 并选中一段文字", "Probing the front app in 3 s: switch to it and select some text"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { Task { await run() } }
    }

    static func run() async {
        var o: [String: Any] = ["date": ISO8601DateFormatter().string(from: Date())]
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        o["app"] = app.bundleIdentifier ?? "?"
        o["axTrusted"] = AXIsProcessTrusted()
        o["postEventAccess"] = CGPreflightPostEventAccess()
        o["secureInput"] = IsSecureEventInputEnabled()
        if #available(macOS 15.4, *) { o["pasteboardAccess"] = String(describing: NSPasteboard.general.accessBehavior) }
        o["profile"] = String(describing: AppProfiles.profile(for: app.bundleIdentifier ?? ""))

        // accessibility read
        let t0 = Date()
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.3)
        var f: CFTypeRef?
        let st = AXUIElementCopyAttributeValue(el, kAXFocusedUIElementAttribute as CFString, &f)
        o["focusedStatus"] = st.rawValue
        if st == .success, let f {
            let e = f as! AXUIElement
            o["role"] = SelectionReader.stringAttr(e, kAXRoleAttribute) ?? ""
            o["subrole"] = SelectionReader.stringAttr(e, kAXSubroleAttribute) ?? ""
            let text = SelectionReader.stringAttr(e, kAXSelectedTextAttribute)
            o["selectedTextLength"] = text.map { ($0 as NSString).length } ?? -1
            o["axReadMs"] = Int(Date().timeIntervalSince(t0) * 1000)
            var s: DarwinBoolean = false
            AXUIElementIsAttributeSettable(e, kAXValueAttribute as CFString, &s); o["valueSettable"] = s.boolValue
            AXUIElementIsAttributeSettable(e, kAXSelectedTextAttribute as CFString, &s); o["selectedTextSettable"] = s.boolValue
            var rv: CFTypeRef?
            o["hasRange"] = AXUIElementCopyAttributeValue(e, kAXSelectedTextRangeAttribute as CFString, &rv) == .success
            var names: CFArray?
            AXUIElementCopyParameterizedAttributeNames(e, &names)
            let pn = (names as? [String]) ?? []
            o["paramAttrs"] = pn
            o["hasTextMarkers"] = pn.contains("AXAttributedStringForTextMarkerRange")
            // write test only in TextEdit, and only when something is selected
            if app.bundleIdentifier == "com.apple.TextEdit", let text, !text.isEmpty, let rv, CFGetTypeID(rv) == AXValueGetTypeID() {
                var cf = CFRange(); AXValueGetValue(rv as! AXValue, .cfRange, &cf)
                let r = NSRange(location: cf.location, length: cf.length)
                let h = WriteHandle(pid: app.processIdentifier, element: e)
                let res = await WriteBack.axReplace(handle: h, range: r, oldFull: text, newFull: text.uppercased())
                o["axWriteResult"] = String(describing: res)
            }
        } else {
            o["axReadMs"] = Int(Date().timeIntervalSince(t0) * 1000)
        }

        // clipboard read (synthesized ⌘C), timing only; content is not logged
        if !(o["secureInput"] as? Bool ?? true) {
            let pb = NSPasteboard.general
            let saved = Pasteboard.save(pb)
            let before = pb.changeCount
            let t1 = Date()
            Keys.post(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
            var waited = 0
            while pb.changeCount == before && waited < 1500 { try? await Task.sleep(nanoseconds: 10_000_000); waited += 10 }
            o["clipboardChanged"] = pb.changeCount != before
            o["clipboardMs"] = Int(Date().timeIntervalSince(t1) * 1000)
            o["clipboardHasHTML"] = pb.types?.contains(.html) ?? false
            o["clipboardLength"] = (pb.string(forType: .string) as NSString?)?.length ?? -1
            o["lostLazyData"] = saved.lostLazyData
            Pasteboard.restore(pb, saved)
        }
        if let d = try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]),
           let line = String(data: d, encoding: .utf8) {
            if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(Data((line + "\n").utf8)); try? h.close() }
            else { try? (line + "\n").write(to: logURL, atomically: true, encoding: .utf8) }
        }
        Toast.show(L.t("探测完成：\(o["app"] ?? "")，已写入 probe.jsonl", "Probe done: \(o["app"] ?? ""), written to probe.jsonl"))
    }
}
#endif
