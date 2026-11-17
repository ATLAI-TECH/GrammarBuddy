// LiveChecker.swift
// "Live check": underline mistakes in place, without selecting anything (asked for by the user on 2026-11-16;
// it reverses design §1.2 for the apps where it is technically possible).
//
// How it works
//   - Every 0.5 s: the focused text element of the front app, read through Accessibility (never the clipboard).
//   - When the text has been still for ~1.2 s, visible paragraphs that changed are checked one at a time.
//   - ONLY a local engine is used (built-in model first). Text is never sent to an API automatically.
//   - Each suggested change is mapped to its screen rectangle (AXBoundsForRange) and underlined in a transparent,
//     click-through overlay. A click on an underlined word opens a small card: Accept / Ignore.
//
// Where it works: apps that expose text ranges and bounds (TextEdit, Notes, Mail, Pages, Safari text areas…).
// Not in Chromium / Electron apps or Word (no usable text geometry), terminals, password managers, secure fields.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI
import NaturalLanguage
import GrammarBuddyKit

struct LiveMark: Identifiable, Equatable {
    let id: String              // paragraph key + change range
    var range: NSRange          // UTF-16 in the element's whole value
    var removed: String
    var inserted: String
    var rect: CGRect            // screen, top-left origin (Accessibility coordinates)
    var paragraphKey: String
    var before = ""             // the word before and after, so an insertion or deletion can be shown in place
    var after = ""

    /// Changes that differ only in letter case, or touch something that looks like an identifier (FLC / flc, Col-0),
    /// are not accepted by a key press: holding ⏎ through a list must not flip a gene name (round 7, W7 opinion).
    var needsDeliberateAccept: Bool {
        let split = { (t: String) in t.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" }).map(String.init) }
        let a = split(removed), b = split(inserted)
        // identifier-like: letters with digits (Col-0, flc-3), or a run of capitals (FLC)
        let idLike = { (w: String) -> Bool in
            let letters = w.filter(\.isLetter)
            // digits only: Character.isNumber is also true for 一 二 三, which made 一至 → 一致 an "identifier"
            if w.contains(where: { $0.isASCII && $0.isNumber }) && !letters.isEmpty { return true }
            return letters.count >= 2 && letters.allSatisfy(\.isUppercase)
        }
        guard a.count == b.count else { return (a + b).contains(where: idLike) && removed.lowercased() == inserted.lowercased() }
        for (x, y) in zip(a, b) where x != y {
            if x.lowercased() == y.lowercased() && (idLike(x) || idLike(y)) { return true }     // FLC ↔ flc
            if idLike(x) && idLike(y) { return true }                                             // Col-0 → Col-1
        }
        return false
    }
}

@MainActor
final class LiveChecker {
    static let shared = LiveChecker()
    static let enabledKey = "gb_live_check"

    var enabled: Bool {
        // On by default (user decision 2026-11-16): checking starts by itself as soon as the cursor is in a text box.
        // It only ever uses a local model, so nothing leaves the Mac without a click.
        get { Store.defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { Store.defaults.set(newValue, forKey: Self.enabledKey); newValue ? start() : stop() }
    }

    private(set) var marks: [LiveMark] = []
    var qaTargetPID: pid_t?
    private(set) var status = ""                       // for Settings and the QA dump
    private var timer: Timer?
    private var element: AXUIElement?
    private var elementPID: pid_t = 0
    private(set) var lastValue = ""
    private var lastChange = Date.distantPast
    private var cache: [String: [Change]] = [:]         // paragraph text → accepted-quality changes
    private var cacheOrder: [String] = []
    private var ignored = Set<String>()                 // "paragraph|removed|inserted"
    private var checking: Task<Void, Never>?
    private var checkingKey: String?
    private var clickMonitor: Any?
    private var otherMonitor: Any?
    private let overlay = LiveOverlay()
    private let card = LiveCard()

    func start() {
        guard timer == nil, enabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let pid = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            Task { @MainActor in
                guard let self, self.reviewing, self.qaTargetPID == nil, pid != self.elementPID else { return }
                self.closeCard()
            }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] e in
            let p = NSEvent.mouseLocation, clicks = e.clickCount
            Task { @MainActor in self?.clicked(at: p, clicks: clicks) }
        }
        otherMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .scrollWheel, .leftMouseDown]) { [weak self] e in
            let type = e.type
            let at = NSEvent.mouseLocation
            Task { @MainActor in
                if type == .leftMouseDown { self?.mouseDownAt = at }
                // key presses are handled by KeyTap while the card is open; a click elsewhere or a scroll closes it
                if type != .keyDown { self?.closeCard() }
                if type == .scrollWheel { self?.refreshRects() }
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        if let m = clickMonitor { NSEvent.removeMonitor(m) }; clickMonitor = nil
        if let m = otherMonitor { NSEvent.removeMonitor(m) }; otherMonitor = nil
        checking?.cancel(); checking = nil; checkingKey = nil
        clear()
    }

    private func clear() {
        marks = []
        overlay.show([])
        if reviewing || card.isVisible { closeCard() }
        element = nil
        lastValue = ""
    }

    // MARK: the loop

    private func tick() {
        guard enabled else { return }
        guard SelectionReader.hasAccessibility else { status = L.t("需要辅助功能权限", "Needs the Accessibility permission"); clear(); return }
        guard let engine = Self.liveEngine() else {
            status = L.t("需要一个本机模型（设置 → AI → 内置模型）", "Needs a local model (Settings → AI → Built-in model)"); clear(); return
        }
        if PanelController.shared.isOpen { overlay.show([]); return }       // the panel has the floor
        // QA can pin a background app (qaTargetPID) so a test doesn't depend on what the user has in front
        let pinned = qaTargetPID.flatMap { NSRunningApplication(processIdentifier: $0) }
        guard let app = pinned ?? NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else { overlay.show([]); card.hide(); return }
        let profile = AppProfiles.profile(for: app.bundleIdentifier ?? "")
        // Chromium / Electron apps expose their text only after being asked (TextGeometry.swift)
        let isWord = profile.reader == .word
        if profile.reader == .clipboard || isWord { AXTree.enable(app) }
        if profile.excluded || profile.readOnly || AppState.shared.hotkeysPaused || IsSecureEventInputEnabled() {
            status = L.t("这个 App 里不能实时标记", "Live check isn't available in this app"); clear(); return
        }
        let el: AXUIElement
        let value: String
        if isWord {
            // one text area per page: work on the page that shows most on screen (it follows scrolling)
            let pages = WordAX.pages(pid: app.processIdentifier)
            guard let page = pages.filter({ $0.visibleArea > 0 }).max(by: { $0.visibleArea < $1.visibleArea }) ?? pages.first else {
                WordAX.assertFlag(pid: app.processIdentifier)
                clear(); status = L.t("正在等 Word 提供文档内容…", "Waiting for Word to expose the document…"); return
            }
            el = page.element; value = page.text
            wordOffset = page.offset
            clipFrame = WordAX.lastViewFrame
            skipFirstParagraph = page.startsMidParagraph; skipLastParagraph = page.endsMidParagraph
        } else {
            guard let f = focusedTextElement(pid: app.processIdentifier) else { clear(); status = ""; return }
            var v: CFTypeRef?
            guard AXUIElementCopyAttributeValue(f, kAXValueAttribute as CFString, &v) == .success, let raw = v as? String else { clear(); return }
            el = f; value = raw
            wordOffset = 0; skipFirstParagraph = false; skipLastParagraph = false
            clipFrame = nil
        }
        let ns = value as NSString
        if ns.length == 0 || ns.length > 30000 { clear(); status = ns.length > 30000 ? L.t("文字太长，不实时检查", "Too long for live check") : ""; return }

        let sameElement = element.map { CFEqual($0, el) } ?? false
        if !sameElement || value != lastValue {
            // typing → wait for a pause; a newly focused field → start right away
            lastChange = sameElement ? Date() : Date().addingTimeInterval(-10)
            element = el; elementPID = app.processIdentifier
            lastValue = value
            rectCache.removeAll()
            if !sameElement { closeCard() }
        }
        rebuildMarks(value: value, el: el)
        guard Date().timeIntervalSince(lastChange) > 0.7, checking == nil else { return }
        // next sentence that has not been checked yet, nearest to the caret first
        // Word reports the visible range in whole-document positions, not page positions: check the whole page there
        var visible = NSRange(location: 0, length: ns.length)
        if !isWord, let v = visibleRange(el), v.length > 0, v.location >= 0, NSMaxRange(v) <= ns.length + 1 { visible = v }
        var todo = paragraphs(of: value)
        if skipFirstParagraph, !todo.isEmpty { todo.removeFirst() }
        if skipLastParagraph, !todo.isEmpty { todo.removeLast() }
        let pending = todo.filter { NSIntersectionRange($0.range, visible).length > 0 && cache[$0.text] == nil && worthChecking($0.text)
            && (failedAt[$0.text].map { Date().timeIntervalSince($0) > 15 } ?? true) }
        let here = caret(el, length: ns.length) ?? visible.location
        func distance(_ r: NSRange) -> Int { here < r.location ? r.location - here : (here > NSMaxRange(r) ? here - NSMaxRange(r) : 0) }
        if let next = pending.min(by: { distance($0.range) < distance($1.range) }) {
            check(next.text, engine: engine)
            status = L.t("实时检查：\(marks.count) 处，还有 \(pending.count) 句在排队", "Live check: \(marks.count) suggestion(s), \(pending.count) sentence(s) queued")
            return
        }
        status = L.t("实时检查：\(marks.count) 处", "Live check: \(marks.count) suggestion(s)")
    }

    /// The engine for live checking: always local. The built-in model is used whenever one is ready, even if the
    /// user's selected engine is LM Studio or an API, so live check doesn't depend on another app being open.
    static func liveEngine() -> EngineConfig? {
        let st = AppState.shared
        // several QA instances share one LM Studio model instead of each loading its own built-in copy
        if Store.defaults.bool(forKey: "gb_live_use_configured"), let e = st.localEngine { return e }
        if let b = st.engines.first(where: { $0.kind == .builtin }) { return b }
        let rec = BuiltInChoice.recommended(ramGB: st.ramGB)
        let ready = BuiltInModels.shared.state(rec.id) == .ready ? rec : BuiltInChoice.catalog.first { BuiltInModels.shared.state($0.id) == .ready }
        if let ready { return EngineConfig(id: "builtin-live", kind: .builtin, name: L.t("内置", "Built-in"), baseURL: "builtin:mlx", model: ready.id) }
        return st.localEngine
    }

    private func focusedTextElement(pid: pid_t) -> AXUIElement? {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.3)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f,
              CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        let el = f as! AXUIElement
        AXUIElementSetMessagingTimeout(el, 0.3)
        let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? ""
        guard role == (kAXTextAreaRole as String) || role == (kAXTextFieldRole as String) else { return nil }
        if SelectionReader.stringAttr(el, kAXSubroleAttribute) == (kAXSecureTextFieldSubrole as String) { return nil }
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue else { return nil }
        // not the address bar, search fields or other toolbar fields (round 7, S7-03: Safari's URL was sent to the model)
        if role == (kAXTextFieldRole as String) {
            if SelectionReader.stringAttr(el, kAXSubroleAttribute) == (kAXSearchFieldSubrole as String) { return nil }
            var cur = el
            for _ in 0..<8 {
                var p: CFTypeRef?
                guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &p) == .success, let p else { break }
                cur = p as! AXUIElement
                let r = SelectionReader.stringAttr(cur, kAXRoleAttribute) ?? ""
                if r == (kAXToolbarRole as String) { return nil }
                if r == (kAXWindowRole as String) || r == "AXWebArea" { break }
            }
        }
        return el
    }

    private func visibleRange(_ el: AXUIElement) -> NSRange? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXVisibleCharacterRangeAttribute as CFString, &v) == .success, let v,
              CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var cf = CFRange()
        return AXValueGetValue(v as! AXValue, .cfRange, &cf) ? NSRange(location: cf.location, length: cf.length) : nil
    }

    struct Para { var range: NSRange; var text: String }

    /// The units that are checked and cached: sentences (user request 2026-11-16: "one sentence at a time, starting
    /// where I am"). Ranges are UTF-16 in `value`; trailing whitespace is left out so a sentence's text is stable.
    func paragraphs(of value: String) -> [Para] {
        var out: [Para] = []
        let tk = NLTokenizer(unit: .sentence)
        tk.string = value
        tk.enumerateTokens(in: value.startIndex..<value.endIndex) { r, _ in
            var sub = value[r]
            while let last = sub.last, last.isWhitespace { sub = sub.dropLast() }
            while let first = sub.first, first.isWhitespace { sub = sub.dropFirst() }
            if !sub.isEmpty {
                // a "sentence" may still span a line break (headings, list items): split at newlines
                var lineStart = sub.startIndex
                while lineStart < sub.endIndex {
                    let lineEnd = sub[lineStart...].firstIndex(of: "\n") ?? sub.endIndex
                    let piece = sub[lineStart..<lineEnd]
                    if !piece.trimmingCharacters(in: .whitespaces).isEmpty {
                        out.append(Para(range: NSRange(piece.startIndex..<piece.endIndex, in: value), text: String(piece)))
                    }
                    lineStart = lineEnd < sub.endIndex ? sub.index(after: lineEnd) : sub.endIndex
                }
            }
            return true
        }
        return out
    }

    /// Caret position in the element's value (Word reports it in whole-document positions).
    private func caret(_ el: AXUIElement, length: Int) -> Int? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &v) == .success, let v,
              CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var cf = CFRange()
        guard AXValueGetValue(v as! AXValue, .cfRange, &cf) else { return nil }
        // Word: every range of a page's text area is in whole-document positions (wordOffset is 0 elsewhere).
        // A page without the caret reports NSNotFound.
        guard cf.location != NSNotFound, cf.location >= wordOffset else { return nil }
        let loc = cf.location - wordOffset
        return loc <= length ? loc : nil
    }

    private func worthChecking(_ text: String) -> Bool {
        if text.range(of: "^\\s*(https?://|www\\.|file:|[\\w.-]+@[\\w.-]+)\\S*\\s*$", options: .regularExpression) != nil { return false }   // a URL or address, not prose
        let words = Tokenizer.tokens(text).filter(\.isWord).count
        return words >= 3 && (text as NSString).length <= 800
    }

    // MARK: checking one paragraph with the local engine

    /// Shown in the menu bar while sentences are being checked (round 7, P7-05 / M7-07: nothing showed it was working).
    var isBusy: Bool { checking != nil }

    private func check(_ text: String, engine e: EngineConfig) {
        checkingKey = text
        AppDelegate.shared?.updateIcon()
        let backend = Engines.backend(for: e)
        let lang = LanguageDirection.detect(text).language.map { LanguageDirection.englishName(LanguageDirectionHelpers.base($0)) }
        let system = Prompts.system(for: .fix, protectedWords: AppState.shared.protectedWords, sourceLanguage: lang)
        checking = Task { [weak self] in
            var raw = ""
            do {
                for try await ev in backend.run(EngineRequest(system: system, text: text), model: e.model) {
                    if Task.isCancelled { return }
                    if case .text(let s) = ev { raw += s }
                    if raw.count > 4 * max(text.count, 40) { break }       // runaway output
                }
            } catch {
                // A check that was cancelled (live check switched off, another field) or that failed (model still
                // loading, engine error) says nothing about the sentence. It used to be stored as "no suggestions",
                // so that sentence was never looked at again (Word test: the first paragraph had no marks after
                // live check was switched off and on).
                let cancelled = Task.isCancelled
                await MainActor.run { self?.checkFailed(text, cancelled: cancelled) }
                return
            }
            if Task.isCancelled { return }
            let out = Cleaner.clean(raw, original: text, operation: .fix)
            let checks = Checks.run(original: text, result: out, operation: .fix, protectedWords: AppState.shared.protectedWords)
            // Only results that pass every check are shown; a live mark must never suggest something risky.
            var changes: [Change] = []
            if !out.isEmpty && !checks.failed { changes = WordDiff.changes(from: text, to: out) }
            if checks.failed || out.isEmpty {
                let line = "\(text.prefix(50))… ⇒ \(out.isEmpty ? "(empty)" : String(out.prefix(160))) | \(String(describing: checks).prefix(300))"
                await MainActor.run { self?.rejected.append(line); if (self?.rejected.count ?? 0) > 20 { self?.rejected.removeFirst() } }
            }
            await MainActor.run { self?.finishCheck(text, changes: changes) }
        }
    }

    private var failedAt: [String: Date] = [:]      // sentences whose check failed: tried again after a while
    private func checkFailed(_ text: String, cancelled: Bool) {
        if checkingKey == text { checking = nil; checkingKey = nil }
        AppDelegate.shared?.updateIcon()
        if !cancelled { failedAt[text] = Date(); if failedAt.count > 200 { failedAt.removeAll() } }
    }

    private func finishCheck(_ text: String, changes: [Change]?, located: Bool = false) {
        // Word: a suggestion that can't be found in the document itself (it touches words that only Accessibility
        // adds, such as "Field" or "Table, 2 Rows", or sits across a field) could never be applied: don't show it.
        if !located, let changes, !changes.isEmpty,
           NSRunningApplication(processIdentifier: elementPID)?.bundleIdentifier == AppProfiles.word,
           let p = paragraphs(of: lastValue).first(where: { $0.text == text }) {
            let value = lastValue, offset = wordOffset
            checking = Task { [weak self] in
                var kept: [Change] = []
                for c in changes {
                    let abs = NSRange(location: p.range.location + c.range.location, length: c.range.length)
                    let r = await Self.wordReplace(range: abs, removed: c.removed, inserted: c.inserted, value: value, offset: offset, write: false)
                    // only a definite "not there" drops it; a scripting error (no permission yet) keeps it
                    if r.ok || (r.message != "notfound" && r.message != "ambiguous") { kept.append(c) } else { self?.wordDropped += 1 }
                }
                if Task.isCancelled { return }
                self?.finishCheck(text, changes: kept, located: true)
            }
            return
        }
        checking = nil; checkingKey = nil
        AppDelegate.shared?.updateIcon()
        cache[text] = changes ?? []
        cacheOrder.append(text)
        if cacheOrder.count > 800 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        tick()          // show this sentence's marks and start the next one at once
    }

    // MARK: marks and their rectangles

    private func rebuildMarks(value: String, el: AXUIElement) {
        var out: [LiveMark] = []
        let frame = clipFrame ?? elementFrame(el)
        for p in paragraphs(of: value) {
            guard let changes = cache[p.text] else { continue }
            let pns = p.text as NSString
            let quotes = Quotes.ranges(in: p.text)       // never suggest changes to what someone said (M7-01)
            for c in changes where !ignored.contains(p.text + "|" + c.removed + "|" + c.inserted) && !Quotes.contains(c.range, in: quotes) {
                // underline the word that changes; a pure insertion marks the word before it
                var r = c.range
                if r.length == 0 {
                    let before = pns.substring(to: r.location) as NSString
                    let ws = before.rangeOfCharacter(from: .whitespaces, options: .backwards)
                    let start = ws.location == NSNotFound ? 0 : NSMaxRange(ws)
                    r = NSRange(location: start, length: max(1, r.location - start))
                }
                let abs = NSRange(location: p.range.location + r.location, length: r.length)
                guard let rect = bounds(el, abs), rect.width > 1, rect.height > 1 else { continue }
                if let frame, !frame.insetBy(dx: -2, dy: -2).contains(CGPoint(x: rect.midX, y: rect.midY)) { continue }   // scrolled out of view
                if clipFrame != nil, let frame, !frame.insetBy(dx: -2, dy: -2).contains(rect) { continue }               // Word: half behind the ribbon
                var mark = LiveMark(id: p.text + "|\(c.range.location)|\(c.range.length)",
                                    range: NSRange(location: p.range.location + c.range.location, length: c.range.length),
                                    removed: c.removed, inserted: c.inserted, rect: rect, paragraphKey: p.text)
                let head = pns.substring(to: c.range.location), tail = pns.substring(from: NSMaxRange(c.range))
                mark.before = head.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
                mark.after = tail.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                out.append(mark)
            }
        }
        if out != marks { marks = out; overlay.show(out, pid: elementPID) } else { overlay.keepInPlace(out, pid: elementPID) }
    }

    private func refreshRects() {
        guard let el = element, !lastValue.isEmpty else { return }
        rectCache.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.rebuildMarks(value: self.lastValue, el: el)
        }
    }

    /// Rectangles are cached while the text is unchanged: in Chromium / Electron each one costs several
    /// text-marker round trips. Scrolling and a 2-second age limit invalidate the cache.
    private var clipFrame: CGRect?             // Word: the document window; marks outside it are not drawn
    private var wordOffset = 0                 // Word: where the current page starts in the document
    private var skipFirstParagraph = false     // Word: paragraphs cut by a page break are not checked
    private var skipLastParagraph = false
    private var rectCache: [String: CGRect] = [:]
    private var rectCacheTime = Date.distantPast

    private func bounds(_ el: AXUIElement, _ r: NSRange) -> CGRect? {
        if Date().timeIntervalSince(rectCacheTime) > 1 { rectCache.removeAll(); rectCacheTime = Date() }
        let key = "\(r.location),\(r.length)"
        if let c = rectCache[key] { return c }
        // Word: AXBoundsForRange on a page's text area takes whole-document positions, not positions in the page's
        // own text (probe on a 3-page document: the page-local index returned text and rectangles of page 1).
        guard let rect = TextGeometry.bounds(el, NSRange(location: r.location + wordOffset, length: r.length)) else { return nil }
        rectCache[key] = rect
        return rect
    }

    private func elementFrame(_ el: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p)
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s)
        var pt = CGPoint.zero, sz = CGSize.zero
        if let p { AXValueGetValue(p as! AXValue, .cgPoint, &pt) }
        if let s { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
        return sz == .zero ? nil : CGRect(origin: pt, size: sz)
    }

    // MARK: click → card → accept / ignore

    private var mouseDownAt: NSPoint = .zero

    private func clicked(at p: NSPoint, clicks: Int) {
        guard enabled, clicks == 1, !marks.isEmpty else { return }
        guard hypot(p.x - mouseDownAt.x, p.y - mouseDownAt.y) <= 6 else { return }     // that was a drag selection
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let ax = CGPoint(x: p.x, y: primaryH - p.y)
        guard let m = marks.first(where: { $0.rect.insetBy(dx: -2, dy: -3).contains(ax) }) else { return }
        open(m, keyboard: false)
        if NSRunningApplication(processIdentifier: elementPID)?.bundleIdentifier == AppProfiles.word { dismissWordPopup(near: m.rect) }
    }

    /// Word shows its own Editor card when a word it has underlined itself is clicked, so one click gave two cards.
    /// Word's card is a small window of Word's next to the word; when one shows up right after the click, Esc is sent
    /// to Word alone (not through the session, so our own key tap never sees it). Nothing is sent if no card appears.
    private(set) var rejected: [String] = []    // QA: sentences whose result failed a safety check (so no marks)
    private(set) var wordPopupsDismissed = 0
    private(set) var wordDropped = 0            // suggestions not shown because Word's own text has no such place
    private func dismissWordPopup(near rect: CGRect, attempt: Int = 0) {
        let pid = elementPID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.reviewing, !self.keyboardReview else { return }
            let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            let zone = rect.insetBy(dx: -40, dy: -40)
            let found = list.contains { w in
                guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid, (w[kCGWindowLayer as String] as? Int) == 0,
                      let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
                let r = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
                return r.width < 520 && r.height < 320 && r.intersects(zone)
            }
            if found {
                for down in [true, false] {
                    CGEvent(keyboardEventSource: CGEventSource(stateID: .combinedSessionState), virtualKey: 53, keyDown: down)?.postToPid(pid)
                }
                self.wordPopupsDismissed += 1
            } else if attempt < 10 {
                self.dismissWordPopup(near: rect, attempt: attempt + 1)
            }
        }
    }

    // MARK: review with the keyboard
    // The card opens only when the user asks for it (a click on an underline, or ⌃⌘J "next suggestion").
    // While it is open: ⏎ accept and move to the next one, ⇥ skip to the next one, Esc close. Any other key closes
    // the card and goes to the app as usual, so ⏎ is never taken away from normal typing.

    private(set) var activeMark: LiveMark?
    private(set) var keysWork = true            // false when the key tap could not be created: the card then says "click"

    /// What VoiceOver says for a card (S7-10: deletions and insertions were read as "to  to .").
    private func spoken(_ m: LiveMark) -> String {
        let n = (marks.firstIndex(of: m) ?? 0) + 1
        let head = L.t("第 \(n) 条，共 \(marks.count) 条：", "Suggestion \(n) of \(marks.count): ")
        if m.removed.isEmpty { return head + L.t("在 \(m.before) 后面加上 \(m.inserted)", "add \(m.inserted) after \(m.before)") }
        if m.inserted.isEmpty { return head + L.t("删除 \(m.removed)", "delete \(m.removed)") }
        return head + L.t("\(m.removed) 改为 \(m.inserted)", "\(m.removed) to \(m.inserted)")
    }

    /// `keyboard` = opened with ⌃⌘J (a review: ⏎ accept and next, ⇥ skip, ⌫ ignore, Esc close).
    /// Opened by a click it is a single card: only ⏎ (accept) and Esc are ours; every other key, ⌫ included, goes to
    /// the app, because someone who clicked into a word may want to edit it by hand (round 8, I8-01 / S8-02).
    func open(_ m: LiveMark, keyboard: Bool = true) {
        if !reviewing {            // a new review: remember where the user was typing (S8-03)
            homeCaret = element.flatMap { caret($0, length: (lastValue as NSString).length) }
            acceptedInReview = 0
        }
        keyboardReview = keyboard
        confirmPending = nil
        activeMark = m
        reviewing = true
        writing = false
        let i = (marks.firstIndex(of: m) ?? 0) + 1
        keysWork = KeyTap.shared.start()
        card.show(mark: m, position: keyboard ? "\(i)/\(marks.count)" : "", keys: keysWork, review: keyboard,
                  accept: { [weak self] in self?.accept(m, advance: keyboard) }, ignore: { [weak self] in self?.ignore(m, advance: keyboard) },
                  ignoreAll: { [weak self] in self?.ignoreParagraph(m) })
        keysWork = KeyTap.shared.start()
        Announcer.say(spoken(m) + (i == 1 ? L.t("。回车采用，Tab 跳过，删除键忽略，Esc 关闭", ". Return accepts, Tab skips, Delete ignores, Escape closes") : ""), high: true)
    }

    func closeCard() {
        if let m = activeMark { resumeAfter = NSMaxRange(m.range) + 1; resumeValue = lastValue }
        if reviewing && acceptedInReview > 0 {
            // put the caret back where the user was typing, shifted by what changed before it
            if let home = homeCaret, let el = element, NSRunningApplication(processIdentifier: elementPID)?.bundleIdentifier != AppProfiles.word {
                _ = WriteBack.setRange(el, NSRange(location: max(0, min(home, (lastValue as NSString).length)), length: 0))
            }
            // a key pressed right after the last accept must not land in the app, however the review ended
            if Date().timeIntervalSince(lastAcceptAt) < 0.8 {
                swallowUntil = lastAcceptAt.addingTimeInterval(0.8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in if self?.reviewing == false { KeyTap.shared.stop() } }
                activeMark = nil; reviewing = false; writing = false; card.hide()
                homeCaret = nil; acceptedInReview = 0
                return                       // the tap stays on for the grace period
            }
        }
        homeCaret = nil; acceptedInReview = 0
        activeMark = nil
        reviewing = false
        writing = false
        card.hide()
        KeyTap.shared.stop()
    }

    /// ⌃⌘J: open the first suggestion at or after the caret (wrapping to the first one).
    func reviewNext() {
        guard enabled else { Toast.show(L.t("实时标记没有打开", "Live check is off")); return }
        let open = marks.filter { !skipped.contains($0.id) }
        guard !open.isEmpty else {
            Toast.show(marks.isEmpty ? L.t("这里没有建议", "No suggestions here") : L.t("剩下的都是你跳过的，再按一次从头看", "Only skipped ones are left; press again to start over"))
            skipped.removeAll()
            return
        }
        // resume after the last card seen if the text hasn't changed since; otherwise start at the caret
        let caretAt = element.flatMap { caret($0, length: (lastValue as NSString).length) } ?? 0
        let from = (resumeValue == lastValue ? resumeAfter : nil) ?? caretAt
        let next = open.first(where: { NSMaxRange($0.range) >= from })          // the mark the caret is in counts
            ?? open.min(by: { abs($0.range.location - from) < abs($1.range.location - from) })!
        self.open(next)
    }

    private var skipped = Set<String>()         // marks passed with the skip key in this review: not offered again
    private var resumeAfter: Int?               // where the last card was, to continue from there
    private var resumeValue = ""

    /// The next mark in document order after `location` that hasn't been skipped. At the end it goes round to the
    /// marks before the starting point, so a review started mid-document covers everything once; nil when nothing
    /// unskipped is left. (Word test, real keys: the review ended with ten marks still above the caret, and the next
    /// ⏎ went into the document as a line break.)
    private func nextMark(after location: Int) -> LiveMark? {
        marks.first(where: { $0.range.location >= location && !skipped.contains($0.id) })
            ?? marks.first(where: { !skipped.contains($0.id) })
    }

    private func openNext(after location: Int) {
        guard let next = nextMark(after: location) else { finishReview(); return }
        open(next)
    }

    /// Review state. `reviewing` is true from the moment a card opens until the review is closed, INCLUDING the
    /// moments when no card is on screen because an accepted change is being written (round 7, S7-01 / I7-01: a second
    /// ⏎ pressed in that gap went to the app and replaced the word just accepted with a line break).
    private(set) var reviewing = false
    private var keyboardReview = true           // false: a single card opened by a click
    private var confirmPending: String?         // a case / identifier change waiting for a second press
    private var homeCaret: Int?                 // where the caret was when the review started
    private var acceptedInReview = 0
    private var lastAcceptAt = Date.distantPast
    private var writing = false                 // an accepted change is on its way into the app
    private var swallowUntil = Date.distantPast // after the last suggestion: eat a stray extra ⏎ for a moment

    static let acceptKeyKey = "gb_live_accept_key"      // "return" (default) or "tab"
    var acceptWithTab: Bool { Store.defaults.string(forKey: Self.acceptKeyKey) == "tab" }

    /// Keys while a review is going on. Returns true when the key was used and must not reach the app.
    func handleKey(_ keyCode: Int, modifiers: CGEventFlags, isRepeat: Bool = false) -> Bool {
        let plain = modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
        let isReturn = keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter
        let acceptKey = acceptWithTab ? keyCode == kVK_Tab : isReturn
        let rawSkip = acceptWithTab ? keyCode == kVK_RightArrow : keyCode == kVK_Tab
        guard reviewing else {
            // just finished: a stray repeat of the accept key must not land in the app (in a chat box ⏎ sends)
            if plain && acceptKey && Date() < swallowUntil { return true }
            return false
        }
        guard plain else { closeCard(); return false }            // ⌘⏎, ⌥⏎, ⇧⏎ … belong to the app
        // skip and ignore keys exist only in a ⌃⌘J review; in a clicked card they belong to the app
        let skipKey = keyboardReview && rawSkip
        let ignoreKey = keyboardReview && (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete)
        if acceptKey || skipKey || ignoreKey || keyCode == kVK_Escape {
            if isRepeat || writing { return true }                // held down, or pressed while the last one is being written
            guard let m = activeMark else { return true }
            if keyCode == kVK_Escape { closeCard(); return true }
            if ignoreKey { ignore(m, advance: true); return true }
            if acceptKey {
                // a case-only or identifier change needs the key twice: one press must never flip FLC to flc (S8-05:
                // it used to have no keyboard way at all)
                if m.needsDeliberateAccept && confirmPending != m.id {
                    confirmPending = m.id
                    card.flash()
                    Announcer.say(L.t("这一条改的是大小写或记号，再按一次确认", "This one changes case or an identifier; press again to confirm"), high: true)
                    return true
                }
                accept(m, advance: keyboardReview)
                return true
            }
            skipped.insert(m.id)             // skip = "not now": it keeps its underline but isn't offered again this round
            if let later = nextMark(after: m.range.location + 1) { open(later) } else { finishReview() }
            return true
        }
        closeCard()          // the user went on typing: get out of the way, the key goes to the app
        return false
    }

    private func finishReview() {
        closeCard()
        resumeAfter = nil; skipped.removeAll()
        swallowUntil = Date().addingTimeInterval(0.8)
        KeyTap.shared.start()            // stays for the grace period; handleKey lets everything else through
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in if self?.reviewing == false { KeyTap.shared.stop() } }
        Toast.show(L.t("这一页的建议都处理完了", "All suggestions here are done"))
    }

    @discardableResult
    func accept(_ m: LiveMark, advance: Bool = false) -> Bool {
        guard let el = element, !writing else { return false }
        card.hide()                      // the review itself stays on: keys are still ours while the change is written
        writing = true
        let pid = elementPID
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        let resume = m.range.location + (m.inserted as NSString).length
        let finish: @MainActor (Bool, String?) -> Void = { [weak self] ok, message in
            guard let self else { return }
            self.writing = false
            if !ok {
                // say why, and do not reopen the same card as if nothing happened (round 7, P7-01)
                Toast.show(message ?? L.t("没能替换这一处（原文可能已经变了）", "Couldn't replace this one (the text may have changed)"))
                self.ignored.insert(m.paragraphKey + "|" + m.removed + "|" + m.inserted)
            } else {
                self.carryOver(accepted: m)
                self.acceptedInReview += 1
                self.lastAcceptAt = Date()
                // keep the remembered caret in step with the text
                if let home = self.homeCaret, m.range.location < home {
                    self.homeCaret = home + (m.inserted as NSString).length - m.range.length
                }
            }
            self.lastChange = Date.distantPast       // re-read at once
            self.tick()
            if advance && self.reviewing { self.openNext(after: ok ? resume : m.range.location + 1) } else { self.closeCard() }
        }
        if bundle == AppProfiles.word {
            // Word ignores writes through Accessibility: replace through its scripting interface, after checking the text there
            Task {
                // with a long context first, then a short one (a field or a footnote mark may sit inside the long one)
                var r = await Self.wordReplace(range: m.range, removed: m.removed, inserted: m.inserted, value: self.lastValue, offset: self.wordOffset, write: true)
                if !r.ok, r.message == "notfound" || r.message == "ambiguous" { r.message = WordBridge.liveNotFound }
                try? await Task.sleep(nanoseconds: 250_000_000)      // let Word publish the changed text
                finish(r.ok, r.ok ? nil : r.message)
            }
            return true
        }
        let handle = WriteHandle(pid: pid, element: el)
        Task {
            var res = await WriteBack.axReplace(handle: handle, range: m.range, oldFull: m.removed, newFull: m.inserted)
            var why: String?
            // Chromium / Electron often ignore AXSelectedText: select the range, then paste (or press Delete for a removal)
            if res != .verified, AXTree.needsSwitch(bundle), WriteBack.axString(el, m.range) == m.removed || m.range.length == 0 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier != pid {
                    why = L.t("这个 App 不在最前面，没法替换。切到它再试", "That app isn't in front, so the change can't be made. Switch to it and try again")
                } else if WriteBack.setRange(el, m.range) {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    if m.inserted.isEmpty {
                        Keys.post(keyCode: CGKeyCode(kVK_Delete), flags: [])
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        res = WriteBack.axString(el, m.range) != m.removed ? .verified : .unverified
                    } else {
                        res = await WriteBack.paste(m.inserted, handle: handle, unknownEditability: false)
                        if res == .pasted { res = .verified }
                    }
                }
            }
            if res == .verified {
                // leave a caret after the new word, not a selection: a following key must not replace it (S7-01)
                _ = WriteBack.setRange(el, NSRange(location: resume, length: 0))
            }
            finish(res == .verified, why)
        }
        return true
    }

    /// Find (and with `write`, change) one piece in Word: with a long context first, then shorter ones, because a
    /// field or a footnote mark inside the context makes it differ from Word's own text.
    static func wordReplace(range: NSRange, removed: String, inserted: String, value: String, offset: Int, write: Bool) async -> (ok: Bool, message: String) {
        var r: (ok: Bool, message: String) = (false, "notfound")
        for width in [28, 9, 4] {
            let c = context(of: range, in: value, width: width)
            r = await WordBridge.liveReplace(start: offset + range.location, removed: removed, inserted: inserted,
                                             before: c.before, after: c.after, write: write)
            if r.ok || (r.message != "notfound" && r.message != "ambiguous") { break }
        }
        return r
    }

    /// The text right before and after `range` on the same line, up to `width` UTF-16 units each way. Used to make
    /// sure a change lands on the right spot in Word.
    static func context(of range: NSRange, in value: String, width: Int) -> (before: String, after: String) {
        let ns = value as NSString
        guard range.location >= 0, NSMaxRange(range) <= ns.length else { return ("", "") }
        var a = max(0, range.location - width), b = min(ns.length, NSMaxRange(range) + width)
        let nl = CharacterSet.newlines
        let left = ns.rangeOfCharacter(from: nl, options: .backwards, range: NSRange(location: a, length: range.location - a))
        if left.location != NSNotFound { a = NSMaxRange(left) }
        let right = ns.rangeOfCharacter(from: nl, options: [], range: NSRange(location: NSMaxRange(range), length: b - NSMaxRange(range)))
        if right.location != NSNotFound { b = right.location }
        // never start or end in the middle of a surrogate pair
        if a > 0, a < ns.length, UTF16.isTrailSurrogate(ns.character(at: a)) { a += 1 }
        if b > 0, b < ns.length, UTF16.isTrailSurrogate(ns.character(at: b)) { b -= 1 }
        a = min(a, range.location); b = max(b, NSMaxRange(range))
        return (ns.substring(with: NSRange(location: a, length: range.location - a)),
                ns.substring(with: NSRange(location: NSMaxRange(range), length: b - NSMaxRange(range))))
    }

    /// Keep the paragraph's other suggestions after one is accepted: store them, shifted, under the new paragraph text.
    /// Without this the paragraph is re-checked, its marks flicker away, and the model returns a new wave of suggestions.
    private func carryOver(accepted m: LiveMark) {
        guard let changes = cache[m.paragraphKey],
              let p = paragraphs(of: lastValue).first(where: { $0.text == m.paragraphKey && NSLocationInRange(m.range.location, NSRange(location: $0.range.location, length: $0.range.length + 1)) })
        else { return }
        let local = NSRange(location: m.range.location - p.range.location, length: m.range.length)
        guard let done = changes.first(where: { NSEqualRanges($0.range, local) && $0.inserted == m.inserted }) else { return }
        let newText = (p.text as NSString).replacingCharacters(in: local, with: m.inserted)
        let delta = (m.inserted as NSString).length - local.length
        var rest: [Change] = []
        for var c in changes where c.id != done.id {
            if c.range.location >= NSMaxRange(local) { c.range.location += delta }
            rest.append(c)
        }
        // When the last carried-over suggestion of a sentence is gone, the sentence is checked once more: an error
        // the first pass missed would otherwise never be flagged (round 7, M7-06).
        if rest.isEmpty { return }
        cache[newText] = rest
        cacheOrder.append(newText)
    }

    func ignore(_ m: LiveMark, advance: Bool = false) {
        card.hide()
        ignored.insert(m.paragraphKey + "|" + m.removed + "|" + m.inserted)
        if let el = element { rebuildMarks(value: lastValue, el: el) }
        if advance && reviewing { openNext(after: m.range.location) } else { closeCard() }
    }

    func ignoreParagraph(_ m: LiveMark) {
        closeCard()
        cache[m.paragraphKey] = []
        if let el = element { rebuildMarks(value: lastValue, el: el) }
    }

    /// QA: front-to-back window order and which window the overlay follows.
    func zOrder() -> String { "overlay window #\(overlay.windowNumber) follows #\(overlay.targetWindow) | " + LiveOverlay.zOrder().joined(separator: " > ") }

    /// QA: one line per mark.
    func dump() -> [String] {
        marks.enumerated().map { "\($0): \($1.removed.isEmpty ? "+" : $1.removed) → \($1.inserted.isEmpty ? "(delete)" : $1.inserted) @ \(Int($1.rect.minX)),\(Int($1.rect.minY)) \(Int($1.rect.width))×\(Int($1.rect.height))" }
    }
}

// MARK: overlay (transparent, click-through)

@MainActor
final class LiveOverlay {
    private var window: NSWindow?
    private let view = UnderlineView()
    private(set) var targetWindow: CGWindowID = 0

    /// The underlines live in a transparent window that sits DIRECTLY ABOVE the target app's window in the window
    /// order, at normal level, and has that window's frame. So whatever covers the app's window (another app, a
    /// menu, a dialog) covers the underlines too, and nothing can be drawn outside that window.
    /// (Before 2026-11-16 this was a floating window over the whole screen: the marks showed through any app.)
    func show(_ marks: [LiveMark], pid: pid_t = 0) {
        guard !marks.isEmpty, let target = Self.targetWindow(pid: pid, marks: marks) else {
            window?.orderOut(nil); targetWindow = 0; return
        }
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        // CG window bounds are top-left based, like Accessibility rectangles
        let frame = CGRect(x: target.bounds.minX, y: primaryH - target.bounds.maxY, width: target.bounds.width, height: target.bounds.height)
        if window == nil {
            let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .normal
            w.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.contentView = view
            window = w
        }
        window?.setFrame(frame, display: false)
        // The app's own popups (Word's Editor card, menus, dialogs) are separate windows in front of the document
        // window: a mark underneath one of them is not drawn, or it would seem to float on the popup.
        let covers = Self.windowsInFront(of: target.id, pid: pid)
        view.rects = marks.filter { m in !covers.contains { $0.intersects(m.rect) } }.map { m in
            CGRect(x: m.rect.minX - target.bounds.minX, y: target.bounds.maxY - m.rect.maxY, width: m.rect.width, height: m.rect.height)
        }
        view.needsDisplay = true
        targetWindow = target.id
        window?.order(.above, relativeTo: Int(target.id))
    }

    /// Called on every tick: the target window may have been raised above us, moved or resized.
    func keepInPlace(_ marks: [LiveMark], pid: pid_t) {
        guard window?.isVisible == true else { return }
        show(marks, pid: pid)
    }

    var windowNumber: Int { window?.isVisible == true ? (window?.windowNumber ?? 0) : 0 }

    /// The on-screen window of `pid` that contains the marks (most mark centres inside it).
    static func targetWindow(pid: pid_t, marks: [LiveMark]) -> (id: CGWindowID, bounds: CGRect)? {
        guard pid != 0, let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        var best: (id: CGWindowID, bounds: CGRect, hits: Int)?
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid, (w[kCGWindowLayer as String] as? Int) == 0,
                  let id = w[kCGWindowNumber as String] as? CGWindowID,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let bounds = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            let hits = marks.filter { bounds.contains(CGPoint(x: $0.rect.midX, y: $0.rect.midY)) }.count
            if hits > (best?.hits ?? 0) { best = (id, bounds, hits) }
        }
        return best.map { ($0.id, $0.bounds) }
    }

    /// Bounds of the same app's on-screen windows that are in front of `target` (any layer).
    static func windowsInFront(of target: CGWindowID, pid: pid_t) -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var out: [CGRect] = []
        for w in list {                                  // front to back
            guard let id = w[kCGWindowNumber as String] as? CGWindowID else { continue }
            if id == target { break }
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid, let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            out.append(CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0))
        }
        return out
    }

    /// QA: front-to-back order of normal windows, to prove where the overlay sits.
    static func zOrder(limit: Int = 10) -> [String] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let me = NSRunningApplication.current.processIdentifier
        return list.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }.prefix(limit).map { w in
            let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let mine = (w[kCGWindowOwnerPID as String] as? pid_t) == me
            return (mine ? "GrammarBuddy(overlay?)" : owner) + " #\(w[kCGWindowNumber as String] as? Int ?? 0) \(Int(b["Width"] ?? 0))×\(Int(b["Height"] ?? 0))"
        }
    }
}

final class UnderlineView: NSView {
    var rects: [CGRect] = []
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemPurple.withAlphaComponent(0.9).setStroke()
        for r in rects {
            let path = NSBezierPath()
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.move(to: NSPoint(x: r.minX + 1, y: r.minY - 1))
            path.line(to: NSPoint(x: r.maxX - 1, y: r.minY - 1))
            path.stroke()
        }
    }
}

// MARK: the card

@MainActor
final class LiveCard {
    private var panel: NSPanel?

    func show(mark m: LiveMark, position: String = "", keys: Bool = true, review: Bool = true, accept: @escaping () -> Void, ignore: @escaping () -> Void, ignoreAll: @escaping () -> Void) {
        hide()
        let view = CardView(mark: m, position: position, keys: keys, review: review, accept: accept, ignore: ignore, ignoreAll: ignoreAll)
        let host = CardHostingView(rootView: view)
        let size = host.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.becomesKeyOnlyIfNeeded = true
        p.contentView = host
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        // ABOVE the word: the app's own spelling / grammar popup (Word's Editor card) opens below it
        var origin = NSPoint(x: m.rect.minX, y: primaryH - m.rect.minY + 6)
        if let vf = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: m.rect.midX, y: primaryH - m.rect.midY)) })?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            if origin.y + size.height > vf.maxY - 4 { origin.y = primaryH - m.rect.maxY - size.height - 6 }   // no room above: below
        }
        p.setFrameOrigin(origin)
        p.orderFrontRegardless()
        panel = p
        lastText = "\(m.removed) → \(m.inserted) [\(position)]"
    }

    private(set) var lastText = ""
    var qaWindow: NSWindow? { panel }

    /// A short nudge when a key press was refused.
    func flash() {
        guard let p = panel else { return }
        let o = p.frame.origin
        p.setFrameOrigin(NSPoint(x: o.x + 5, y: o.y))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { p.setFrameOrigin(o) }
    }

    func hide() { panel?.orderOut(nil); panel = nil }
    var isVisible: Bool { panel != nil }
}

private final class CardHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct CardView: View {
    let mark: LiveMark
    var position = ""
    var keys = true
    var review = true
    var accept: () -> Void
    var ignore: () -> Void
    var ignoreAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if mark.removed.isEmpty {
                    // an insertion is shown between its neighbours: "you [a] 15%"
                    Text(mark.before).foregroundStyle(.secondary)
                    Text(mark.inserted.trimmingCharacters(in: .whitespaces)).foregroundStyle(.green).fontWeight(.semibold).underline()
                    Text(mark.after).foregroundStyle(.secondary)
                } else if mark.inserted.isEmpty {
                    Text(mark.before).foregroundStyle(.secondary)
                    Text(mark.removed.trimmingCharacters(in: .whitespaces)).strikethrough().foregroundStyle(.red)
                    Text(mark.after).foregroundStyle(.secondary)
                    Text(L.t("（删除）", "(delete)")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(mark.removed.visibleWhitespaceIfOnlySpace).strikethrough().foregroundStyle(.red)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                    Text(mark.inserted.visibleWhitespaceIfOnlySpace).foregroundStyle(.green).fontWeight(.semibold)
                }
                Spacer(minLength: 12)
                if !position.isEmpty { Text(position).font(.caption2).foregroundStyle(.tertiary) }
            }
            HStack(spacing: 8) {
                // drawn by hand: a system prominent button turns grey in a panel that isn't the key window (I8-05)
                Button(action: accept) {
                    Text(L.t("采用", "Accept")).font(.callout.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
                Button(L.t("忽略", "Ignore"), action: ignore).controlSize(.small)
                Button(L.t("这句都忽略", "Ignore sentence"), action: ignoreAll).controlSize(.small).buttonStyle(.link)
            }
            if !keys {
                Text(L.t("按键现在不可用，请用鼠标点", "Keys aren't available right now; please click")).font(.caption2).foregroundStyle(.orange)
            } else {
                let tab = LiveChecker.shared.acceptWithTab
                let acceptKey = tab ? "⇥" : "⏎"
                let hint: String = mark.needsDeliberateAccept
                    ? L.t("改的是大小写或记号：\(acceptKey) 按两次确认 · Esc 关闭", "Changes case or an identifier: press \(acceptKey) twice · Esc close")
                    : (review ? L.t("\(acceptKey) 采用并到下一条 · \(tab ? "→" : "⇥") 跳过 · ⌫ 忽略 · Esc 关闭", "\(acceptKey) accept, next · \(tab ? "→" : "⇥") skip · ⌫ ignore · Esc close")
                              : L.t("\(acceptKey) 采用 · Esc 关闭 · ⌃⌘J 逐条过一遍", "\(acceptKey) accept · Esc close · ⌃⌘J review all"))
                Text(hint).font(.caption2).foregroundStyle(mark.needsDeliberateAccept ? .orange : .secondary)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("GrammarBuddy 建议：\(mark.removed) 改为 \(mark.inserted)", "GrammarBuddy suggests: \(mark.removed) to \(mark.inserted)"))
    }
}

// MARK: keys while the card is open

/// A session event tap that exists only while a suggestion card is open. It lets ⏎ / ⇥ / Esc act on the card and
/// keeps them away from the app; every other key passes through untouched. Needs the Accessibility permission.
final class KeyTap {
    static let shared = KeyTap()
    private var tap: CFMachPort?

    /// The tap is created once and then only enabled / disabled. (Round 7, S7-05: creating one per card and merely
    /// disabling it left a pile of dead taps behind.)
    @discardableResult
    @MainActor func start() -> Bool {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true); return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // re-enable only while a review is on; otherwise stay out of the way
                let on = MainActor.assumeIsolated { LiveChecker.shared.reviewing }
                if on, let t = KeyTap.shared.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            // the tap's run-loop source is on the main run loop, so this runs on the main thread
            let used = MainActor.assumeIsolated { LiveChecker.shared.handleKey(code, modifiers: flags, isRepeat: isRepeat) }
            return used ? nil : Unmanaged.passUnretained(event)
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: callback, userInfo: nil) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    @MainActor func stop() {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
    }
}
