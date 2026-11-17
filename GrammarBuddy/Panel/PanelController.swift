// PanelController.swift
// Window and keyboard model (design §2.2–2.3): a non-activating NSPanel that becomes key. GrammarBuddy does
// not become the active app, so the original app's menu bar and selection stay. Actions run on key-up, and only
// for key-downs the panel itself received, so a held ⏎ never leaks into the original app.

import AppKit
import SwiftUI
import Carbon.HIToolbox
import GrammarBuddyKit

final class GBPanel: NSPanel {
    var router: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // a real first click on a non-key panel would only make it key and be swallowed: take key, then deliver it
        if event.type == .leftMouseDown && !isKeyWindow { makeKey() }
        if event.type == .keyDown || event.type == .keyUp, let router, router(event) { return }
        super.sendEvent(event)
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()
    private(set) var panel: GBPanel?
    private(set) var model: PanelModel?
    private var sourceApp: NSRunningApplication?
    private var downKeys = Set<UInt16>()
    private var resignObserver: Any?
    private var hosting: NSHostingController<PanelView>?

    var isOpen: Bool { panel?.isVisible ?? false }
    var sourcePID: pid_t? { sourceApp?.processIdentifier }

    // MARK: show

    func show(outcome: ReadOutcome?, failure: ReadFailure?, operation: TextOperation, app: NSRunningApplication?, qa: Bool = false) {
        closeSilently()
        SelectionWatcher.shared.hide()
        userResized = false
        sourceApp = app
        returnWindow = (app?.processIdentifier == NSRunningApplication.current.processIdentifier) ? NSApp.keyWindow : nil
        let m = PanelModel()
        m.qaSimulated = qa
        m.onClose = { [weak self] in self?.close() }
        m.onYieldKeyboard = { [weak self] in await self?.yieldKeyboard() }
        m.onReclaimKeyboard = { [weak self] in self?.reclaimKeyboard() }
        model = m

        let p = GBPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
                        styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
                        backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isMovableByWindowBackground = false   // clicks on changes must never become a window drag; drag by the header
        p.isReleasedWhenClosed = false
        p.delegate = self
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.standardWindowButton(.closeButton)?.isHidden = true   // the panel has its own ✕ (§2.2)
        p.setAccessibilityTitle("GrammarBuddy")
        p.router = { [weak self] e in self?.route(e) ?? false }
        let hc = NSHostingController(rootView: PanelView(m: m, close: { [weak self] in self?.close() },
                                                     act: { [weak m] a in Task { await m?.perform(a) } },
                                                     resize: { [weak self] _ in DispatchQueue.main.async { self?.fit() } }))
        hc.sizingOptions = []
        hosting = hc
        p.contentView = hc.view
        panel = p

        m.sourceBundle = app?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : app?.bundleIdentifier
        m.start(outcome: outcome, failure: failure, operation: operation, appName: app?.localizedName ?? "")
        position(p, bounds: outcome?.bounds, window: outcome?.windowFrame)
        p.makeKeyAndOrderFront(nil)      // key, but the app is not activated (§2.2)
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.didLeave() }
        }
    }

    /// Below the selection when known; otherwise inside the top-right of the app's focused window (§2.2).
    private func position(_ p: NSPanel, bounds: CGRect?, window: CGRect?) {
        p.layoutIfNeeded()
        let size = NSSize(width: 480, height: min(420, max(160, p.contentView?.fittingSize.height ?? 260)))
        guard let screen = NSScreen.main else { p.center(); return }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        var origin: NSPoint
        if let b = bounds, b.width > 0 || b.height > 0 {
            // AX rects are top-left based
            origin = NSPoint(x: b.minX, y: primaryH - b.maxY - size.height - 8)
        } else if let w = window {
            origin = NSPoint(x: w.maxX - size.width - 24, y: primaryH - w.minY - size.height - 60)
        } else {
            let f = screen.visibleFrame
            origin = NSPoint(x: f.maxX - size.width - 40, y: f.maxY - size.height - 40)
        }
        let vf = (NSScreen.screens.first { $0.frame.contains(origin) } ?? screen).visibleFrame
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        p.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// Height follows the content up to 420 pt; the top edge stays put; a size the user dragged wins (§2.2).
    private var userResized = false
    func fit() {
        guard let p = panel, let v = p.contentView, !userResized else { return }
        _ = v
        let want = hosting?.sizeThatFits(in: NSSize(width: p.frame.width, height: 10000)).height ?? 260
        let titleBar = p.frame.height - p.contentLayoutRect.height   // the view ignores the safe area
        let h = min(420, max(140, want - titleBar))
        guard abs(p.frame.height - h) > 2 else { return }
        var f = p.frame
        f.origin.y += f.height - h
        f.size.height = h
        p.setFrame(f, display: true, animate: false)
    }
    func windowDidEndLiveResize(_ notification: Notification) { userResized = true }

    // MARK: leave / come back (§2.2)

    private func didLeave() {
        guard let m = model, panel?.isVisible == true else { return }
        // our own windows (language download, settings) are not "leaving"
        if let key = NSApp.keyWindow, key !== panel { return }
        m.leftPanel = true
    }

    func bringBack() {
        guard let p = panel else { return }
        p.makeKeyAndOrderFront(nil)
    }

    func close() {
        if let m = model { m.cancel() }
        closeSilently()
    }

    /// Our own window the panel came from (onboarding, test window): it gets the keyboard back on close (L5-07).
    private weak var returnWindow: NSWindow?

    private func closeSilently() {
        if let o = resignObserver { NotificationCenter.default.removeObserver(o); resignObserver = nil }
        panel?.orderOut(nil)
        if let w = returnWindow { w.makeKeyAndOrderFront(nil); returnWindow = nil }
        panel = nil
        model = nil
        downKeys.removeAll()
    }

    func windowWillClose(_ notification: Notification) { model?.cancel() }

    // MARK: keyboard hand-off for paste (§4.5)

    func yieldKeyboard() async {
        // wait for ⏎ and modifiers to be released
        for _ in 0..<50 where !NSEvent.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        panel?.orderOut(nil)
        for _ in 0..<20 where NSApp.keyWindow != nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func reclaimKeyboard() { panel?.makeKeyAndOrderFront(nil) }

    // MARK: key routing (§2.3)

    private func route(_ e: NSEvent) -> Bool {
        guard let m = model else { return false }
        // IME composing: the panel answers no shortcut, and the key-up of the confirming ⏎ doesn't count (§2.3)
        if let tv = panel?.firstResponder as? NSTextView, tv.hasMarkedText() { downKeys.remove(e.keyCode); return false }
        let cmd = e.modifierFlags.contains(.command), opt = e.modifierFlags.contains(.option), shift = e.modifierFlags.contains(.shift)
        let inText = (panel?.firstResponder as? NSTextView)?.isEditable == true

        if e.type == .keyDown {
            if inText && !cmd && e.keyCode != UInt16(kVK_Escape) && !(e.keyCode == UInt16(kVK_Return) && !shift) { return false }
            if inText && e.keyCode == UInt16(kVK_Return) && shift { return false }
            if cmd && !opt, let ch = e.charactersIgnoringModifiers?.lowercased(), ["a", "x", "v", "z"].contains(ch), inText { return false }
            downKeys.insert(e.keyCode)
            // standard editing keys inside read-only results (⌘C on a selection, ⌘A)
            if cmd, e.charactersIgnoringModifiers == "c", let tv = panel?.firstResponder as? NSTextView, tv.selectedRange().length > 0 {
                downKeys.remove(e.keyCode); return false
            }
            if cmd, e.charactersIgnoringModifiers == "a" { downKeys.remove(e.keyCode); return false }
            return isOurKey(e) || e.keyCode == UInt16(kVK_Return)
        }
        // keyUp: act only for key-downs we received
        guard downKeys.remove(e.keyCode) != nil else { return false }
        return handle(e, m: m, cmd: cmd, opt: opt, inText: inText)
    }

    private func isOurKey(_ e: NSEvent) -> Bool {
        let code = Int(e.keyCode)
        if [kVK_Return, kVK_Escape, kVK_UpArrow, kVK_DownArrow, kVK_Space, kVK_ANSI_KeypadEnter].contains(code) { return true }
        if e.modifierFlags.contains(.command) { return true }
        return false
    }

    private func handle(_ e: NSEvent, m: PanelModel, cmd: Bool, opt: Bool, inText: Bool) -> Bool {
        let code = Int(e.keyCode)
        let ch = e.charactersIgnoringModifiers?.lowercased() ?? ""
        if code == kVK_Escape { close(); return true }
        if cmd, ["q", "w", "h"].contains(ch) { close(); return true }      // only closes the panel (§2.3)
        if cmd, let n = Int(ch), (1...4).contains(n) { m.switchOperation(TextOperation.allCases[n - 1]); return true }
        if cmd && ch == "r" { m.run(); return true }
        if cmd && ch == "d" { m.showDiff.toggle(); return true }
        if cmd && ch == "l" && m.operation == .translate { m.showLanguageMenu.toggle(); return true }
        if code == kVK_Return || code == kVK_ANSI_KeypadEnter {
            switch m.phase {
            case .input: m.submitManual(); return true
            case .askConsent: m.allowAPI(always: false); return true      // ⏎ = just this once (G5-05)
            case .askSource: m.confirmSourceAndRun(); return true
            case .done: break
            default: return true        // result not finished: ⏎ and ⌘⏎ do nothing (§2.3)
            }
            guard let r = m.recommendation else { return true }
            if cmd { Task { await m.perform(m.capture?.via == .word ? .trackedChange : .replace) } }
            else if opt { Task { await m.perform(.insertBelow) } }
            else { Task { await m.perform(r.enter) } }
            return true
        }
        if cmd && ch == "c" { Task { await m.perform(.copy) }; return true }
        if m.phase == .done && m.showDiff && !m.changes.isEmpty && !inText {
            if code == kVK_DownArrow { m.focusedChange = min(m.changes.count - 1, m.focusedChange + 1); Announcer.say(m.changeLabel(m.focusedChange), high: false); return true }
            if code == kVK_UpArrow { m.focusedChange = max(0, m.focusedChange - 1); Announcer.say(m.changeLabel(m.focusedChange), high: false); return true }
            if code == kVK_Space { m.toggle(m.focusedChange); return true }
        }
        return cmd
    }
}

/// The 2-second strip after a write (§2.2).
@MainActor
enum Toast {
    private static var window: NSPanel?
    static var last: String?

    static func show(_ text: String) {
        last = text
        QAHarness.shared.log("toast: " + text)
        window?.orderOut(nil)
        let label = NSHostingView(rootView: Text(text).font(.callout).padding(.horizontal, 14).padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule()))
        let size = label.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.level = .statusBar; p.ignoresMouseEvents = true
        p.contentView = label
        if let f = NSScreen.main?.visibleFrame { p.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.minY + 80)) }
        p.orderFrontRegardless()
        window = p
        Announcer.say(text, high: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if window === p { p.orderOut(nil); window = nil } }
    }
}

enum Permissions {
    static func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    static func openAutomation() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }
    static func requestAccessibilityPrompt() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
