// TextGeometry.swift
// Screen rectangles for text ranges in other apps, and switching on the accessibility tree of Chromium / Electron apps.
//
// Why this exists (probe results 2026-11-16, docs/3_…md):
//   - Chrome, VS Code, Obsidian, Slack… expose nothing through Accessibility until an assistive app asks.
//     Electron apps turn their tree on when AXManualAccessibility is set on the application element; Chrome reacts to
//     AXEnhancedUserInterface / AXManualAccessibility too (it returns an error code but the tree appears).
//   - In those apps AXBoundsForRange answers 0×0. The real geometry comes from text markers:
//     AXTextMarkerForIndex (Chrome) or line-based markers (Electron) → AXTextMarkerRangeForUnorderedTextMarkers
//     → AXBoundsForTextMarkerRange.

import AppKit
import ApplicationServices
import GrammarBuddyKit

// Not in the public headers, exported by HIServices; used by many accessibility tools to split a marker range.
@_silgen_name("AXTextMarkerRangeCopyStartMarker")
private func AXTextMarkerRangeCopyStartMarker(_ range: CFTypeRef) -> Unmanaged<CFTypeRef>?
@_silgen_name("AXTextMarkerRangeCopyEndMarker")
private func AXTextMarkerRangeCopyEndMarker(_ range: CFTypeRef) -> Unmanaged<CFTypeRef>?

@MainActor
enum AXTree {
    private static var enabled = Set<pid_t>()

    /// Ask a Chromium / Electron app to build its accessibility tree. Cheap to call repeatedly.
    /// Returns true the first time it is switched on (the tree needs a moment to appear).
    @discardableResult
    static func enable(_ app: NSRunningApplication) -> Bool {
        let pid = app.processIdentifier
        guard !enabled.contains(pid) else { return false }
        enabled.insert(pid)
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        // Chrome-family browsers only answer to the older switch on some versions
        // Word builds its document text areas only while this is set, and takes a few seconds to do it (probe 2026-11-16).
        // The call returns an error code in Word and Chrome, yet the flag reads back as true afterwards.
        if isChromeFamily(app.bundleIdentifier ?? "") || app.bundleIdentifier == AppProfiles.word {
            AXUIElementSetAttributeValue(el, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        return true
    }

    static func isChromeFamily(_ bundle: String) -> Bool {
        ["com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "org.chromium.Chromium"].contains(bundle)
    }

    /// Apps that need the switch: the Chromium / Electron list in AppProfiles (reader == .clipboard).
    static func needsSwitch(_ bundle: String) -> Bool { AppProfiles.clipboardReaders.contains(bundle) }
}

/// One page of a Word document as Accessibility exposes it.
struct WordPage {
    var element: AXUIElement
    var text: String            // this page's text, "\r" already turned into "\n" (same length)
    var offset: Int             // where the page starts in the whole document (AXSharedCharacterRange)
    var startsMidParagraph: Bool
    var endsMidParagraph: Bool
    var focused: Bool
    var isBody = true                  // false: header, footer, footnote, comment or revision balloon
    var frame: CGRect = .zero          // on screen, Accessibility coordinates
    var visibleArea: CGFloat = 0       // how much of the page is inside the document view
}

@MainActor
enum WordAX {
    private static var lastAssert = Date.distantPast
    /// Frame of the document window at the last `pages` call; marks outside it are not drawn.
    private(set) static var lastViewFrame: CGRect = .zero

    static func frame(of el: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p)
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s)
        var pt = CGPoint.zero, sz = CGSize.zero
        if let p { AXValueGetValue(p as! AXValue, .cgPoint, &pt) }
        if let s { AXValueGetValue(s as! AXValue, .cgSize, &sz) }
        return sz == .zero ? nil : CGRect(origin: pt, size: sz)
    }

    /// Word builds a document's text areas only after AXEnhancedUserInterface is set, and a document opened later
    /// needs the flag asserted again. Called (throttled) whenever no text area is found.
    static func assertFlag(pid: pid_t) {
        guard Date().timeIntervalSince(lastAssert) > 2 else { return }
        lastAssert = Date()
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    /// The pages of the front document: AXWindow → … → AXLayoutArea → AXGroup → AXGroup → AXTextArea, one per page.
    /// Keyboard focus sits on the text area of the page with the caret (or on a container when Word is in the background).
    static func pages(pid: pid_t, all: Bool = false) -> [WordPage] {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.5)
        var w: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &w) == .success, let w else { return [] }
        var visited = 0
        // (text area, depth below the AXLayoutArea, its page group, whether its own group also holds a layout area)
        var areas: [(el: AXUIElement, depth: Int, page: AXUIElement?, besideLayout: Bool)] = []
        func kids(_ el: AXUIElement) -> [AXUIElement] {
            var k: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &k) == .success else { return [] }
            return (k as? [AXUIElement]) ?? []
        }
        func find(_ el: AXUIElement, _ depth: Int, layoutDepth: Int?, page: AXUIElement?, besideLayout: Bool) {
            visited += 1
            guard depth < 14, visited < 900, areas.count < 80 else { return }
            let role = SelectionReader.stringAttr(el, kAXRoleAttribute) ?? ""
            if let d = layoutDepth, role == (kAXTextAreaRole as String) { areas.append((el, d, page, besideLayout)); return }
            // only descend where the document can be: skip the ribbon and toolbars
            if role == "AXTabGroup" || role == "AXToolbar" || role == "AXMenuBar" { return }
            let ks = Array(kids(el).prefix(60))
            let hasLayoutKid = layoutDepth != nil && ks.contains { SelectionReader.stringAttr($0, kAXRoleAttribute) == "AXLayoutArea" }
            for k in ks {
                if let d = layoutDepth {
                    find(k, depth + 1, layoutDepth: d + 1, page: page, besideLayout: hasLayoutKid)
                } else {
                    let inLayout = role == "AXLayoutArea"
                    find(k, depth + 1, layoutDepth: inLayout ? 0 : nil, page: inLayout ? k : nil, besideLayout: false)
                }
            }
        }
        find(w as! AXUIElement, 0, layoutDepth: nil, page: nil, besideLayout: false)
        var focusedEl: CFTypeRef?
        AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focusedEl)
        var out: [WordPage] = []
        // Which text area is the page's body? A page also has a header, a footer, a footnote area, footnote reference
        // marks, comment and revision balloons, all of them text areas. Independent of Word's UI language: the body sits
        // two levels below the page (page → group → text area), its group holds no layout area of its own (the footnote
        // area's does), and of the candidates left (header, body, footer) it is the tallest.
        var bodyOf: [Int: Int] = [:]      // page hash → index in `areas`
        for (i, a) in areas.enumerated() where a.depth == 2 && !a.besideLayout {
            guard let pg = a.page else { continue }
            let key = Int(CFHash(pg))
            let h = frame(of: a.el)?.height ?? 0
            if let j = bodyOf[key], (frame(of: areas[j].el)?.height ?? 0) >= h { continue }
            bodyOf[key] = i
        }
        let bodies = Set(bodyOf.values)
        for (i, a) in areas.enumerated() {
            let el = a.el
            let isBody = bodies.contains(i)
            if !isBody && !all { continue }
            var v: CFTypeRef?, sr: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &v) == .success, let raw = v as? String else { continue }
            var cf = CFRange(location: 0, length: 0)
            if AXUIElementCopyAttributeValue(el, "AXSharedCharacterRange" as CFString, &sr) == .success, let sr, CFGetTypeID(sr) == AXValueGetTypeID() {
                AXValueGetValue(sr as! AXValue, .cfRange, &cf)
            }
            let prevEndsPara = out.last.map { $0.text.hasSuffix("\n") } ?? true
            out.append(WordPage(element: el, text: raw.replacingOccurrences(of: "\r", with: "\n"), offset: cf.location,
                                startsMidParagraph: !prevEndsPara, endsMidParagraph: false,
                                focused: focusedEl.map { CFEqual($0, el) } ?? false, isBody: isBody))
        }
        for i in out.indices.dropLast() { out[i].endsMidParagraph = !out[i].text.hasSuffix("\n") }
        // which pages are on screen: intersect each page with the window (the document view scrolls inside it)
        // The document shows inside a scroll area that is smaller than the window (the ribbon sits above it): text that
        // has scrolled up behind the ribbon is not on screen. (Word test: marks were drawn on top of the toolbar.)
        var view = frame(of: w as! AXUIElement) ?? .zero
        if let pg = areas.first?.page {
            var cur = pg
            for _ in 0..<4 {
                var p: CFTypeRef?
                guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &p) == .success, let p else { break }
                cur = p as! AXUIElement
                if SelectionReader.stringAttr(cur, kAXRoleAttribute) == (kAXScrollAreaRole as String) {
                    if let f = frame(of: cur) { view = view.isEmpty ? f : view.intersection(f) }
                    break
                }
            }
        }
        lastViewFrame = view
        for i in out.indices {
            let f = frame(of: out[i].element) ?? .zero
            out[i].frame = f
            let x = f.intersection(view)
            out[i].visibleArea = x.isNull ? 0 : x.width * x.height
        }
        return out
    }
}

enum TextGeometry {
    static func param(_ el: AXUIElement, _ name: String, _ arg: CFTypeRef) -> CFTypeRef? {
        var out: CFTypeRef?
        return AXUIElementCopyParameterizedAttributeValue(el, name as CFString, arg, &out) == .success ? out : nil
    }

    static func rect(_ v: CFTypeRef?) -> CGRect? {
        guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var r = CGRect.zero
        return AXValueGetValue(v as! AXValue, .cgRect, &r) && r.width > 0.5 && r.height > 0.5 ? r : nil
    }

    /// Rectangle of a UTF-16 range of the element's value, in Accessibility coordinates (top-left origin).
    static func bounds(_ el: AXUIElement, _ r: NSRange) -> CGRect? {
        var cf = CFRange(location: r.location, length: r.length)
        if let v = AXValueCreate(.cfRange, &cf), let out = rect(param(el, kAXBoundsForRangeParameterizedAttribute as String, v)) { return out }
        // Chromium / Electron: through text markers
        guard let a = marker(el, at: r.location), let b = marker(el, at: NSMaxRange(r)),
              let range = param(el, "AXTextMarkerRangeForUnorderedTextMarkers", [a, b] as CFArray) else { return nil }
        return rect(param(el, "AXBoundsForTextMarkerRange", range))
    }

    /// Text marker for a character index.
    static func marker(_ el: AXUIElement, at index: Int) -> CFTypeRef? {
        if let m = param(el, "AXTextMarkerForIndex", index as CFNumber) { return m }
        // No index → marker call (Electron): find the line, take the marker at its start, step to the index.
        if let lineNo = param(el, kAXLineForIndexParameterizedAttribute as String, index as CFNumber) as? Int,
           let lineRangeV = param(el, kAXRangeForLineParameterizedAttribute as String, lineNo as CFNumber),
           CFGetTypeID(lineRangeV) == AXValueGetTypeID(),
           let lineMarkers = param(el, "AXTextMarkerRangeForLine", lineNo as CFNumber),
           var m = AXTextMarkerRangeCopyStartMarker(lineMarkers)?.takeRetainedValue() {
            var lr = CFRange()
            AXValueGetValue(lineRangeV as! AXValue, .cfRange, &lr)
            var steps = index - lr.location
            guard steps >= 0, steps <= 2000 else { return nil }
            while steps > 0 {
                guard let next = param(el, "AXNextTextMarkerForTextMarker", m) else { return nil }
                m = next; steps -= 1
            }
            return m
        }
        // Last resort: walk from the start of the element (short texts only).
        guard index <= 1500 else { return nil }
        var startV: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, "AXStartTextMarker" as CFString, &startV) == .success, var m = startV else { return nil }
        if let own = param(el, "AXTextMarkerRangeForUIElement", el), let s = AXTextMarkerRangeCopyStartMarker(own)?.takeRetainedValue() { m = s }
        for _ in 0..<index {
            guard let next = param(el, "AXNextTextMarkerForTextMarker", m) else { return nil }
            m = next
        }
        return m
    }
}
