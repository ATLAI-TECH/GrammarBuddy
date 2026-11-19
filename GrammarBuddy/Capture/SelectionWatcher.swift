// SelectionWatcher.swift
// "Select, then click": after a drag-selection or double-click in another app, a small button appears near the
// pointer; one click runs Fix or Translate. Nothing is read through the clipboard and nothing is sent anywhere
// until the user clicks (the shortcuts ⌃⌘G / ⌃⌘T still work the same way).
//
// - Only mouse events are watched (global monitor), never typing.
// - Apps whose selection can be read through Accessibility: the button appears only if there really is a selection.
// - Chromium / Electron apps and Word (no cheap way to check): the button appears after a drag or double-click;
//   clicking it reads the selection the usual way.
// - Never in excluded apps (password managers), never while Secure Input is on, never over our own windows.

import AppKit
import SwiftUI
import Carbon.HIToolbox
import GrammarBuddyKit

@MainActor
final class SelectionWatcher {
    static let shared = SelectionWatcher()
    static let enabledKey = "gb_selection_bubble"

    private var monitors: [Any] = []
    private var downPoint: NSPoint = .zero
    private var bubble: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var bubbleApp: pid_t = 0

    var enabled: Bool {
        get { Store.defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { Store.defaults.set(newValue, forKey: Self.enabledKey); newValue ? start() : stop() }
    }

    func start() {
        guard monitors.isEmpty, enabled else { return }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] e in
            let p = NSEvent.mouseLocation
            Task { @MainActor in self?.downPoint = p; self?.hide() }
            _ = e
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] e in
            let p = NSEvent.mouseLocation, clicks = e.clickCount
            Task { @MainActor in self?.mouseUp(at: p, clicks: clicks) }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .scrollWheel, .rightMouseDown], handler: { [weak self] e in
            let isEsc = e.type == .keyDown && e.keyCode == UInt16(kVK_Escape)
            Task { @MainActor in
                self?.hide()
                // Esc always gets rid of our windows, also when the panel is open but the user is typing in their app
                if isEsc, PanelController.shared.isOpen, PanelController.shared.panel?.isKeyWindow != true { PanelController.shared.close() }
            }
        }) { monitors.append(m) }
        // Selecting with the keyboard (⇧ + arrows, ⌘A, ⇧⌘→ …) shows the same buttons, and then they take keys:
        // ⏎ Polish, ⇥ Translate, Esc away. (User, 2026-11-19: "selecting a sentence with the keyboard never shows
        // the button".) Looked at when the keys are released and the selection has settled.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] e in
            let code = Int(e.keyCode), f = e.modifierFlags
            let arrows = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown]
            let selecting = (f.contains(.shift) && arrows.contains(code)) || (f.contains(.command) && code == kVK_ANSI_A)
            guard selecting else { return }
            Task { @MainActor in self?.keyboardSelectionChanged() }
        }) { monitors.append(m) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
        hide()
    }

    // MARK: detection

    private func mouseUp(at p: NSPoint, clicks: Int) {
        let dragged = hypot(p.x - downPoint.x, p.y - downPoint.y) > 6
        guard dragged || clicks >= 2 else { return }
        guard !PanelController.shared.isOpen || PanelController.shared.panel?.isKeyWindow != true else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
        let profile = AppProfiles.profile(for: app.bundleIdentifier ?? "")
        if profile.excluded || IsSecureEventInputEnabled() || AppState.shared.hotkeysPaused || AppState.shared.isDisabled(app.bundleIdentifier) { return }
        // let the app finish updating its selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
            if profile.reader == .clipboard { AXTree.enable(app) }
            if profile.reader == .clipboard, SelectionReader.hasAccessibility, let known = Self.selectionState(pid: app.processIdentifier) {
                if known { self.show(at: p, app: app) }    // the tree answered: show only when something is selected
            } else if profile.reader == .clipboard || profile.reader == .word {
                self.show(at: p, app: app)                 // can't check cheaply; clicking will read
            } else if SelectionReader.hasAccessibility, Self.hasSelection(pid: app.processIdentifier) {
                self.show(at: p, app: app)
            }
        }
    }

    private var keyWork: DispatchWorkItem?
    private(set) var keyboardMode = false       // the buttons were brought up by a keyboard selection: they take ⏎ / ⇥ / Esc

    private func keyboardSelectionChanged() {
        keyWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.showForKeyboardSelection() }
        keyWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)       // after the last key of a run
    }

    private func showForKeyboardSelection() {
        guard enabled, SelectionReader.hasAccessibility, !PanelController.shared.isOpen,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else { return }
        let profile = AppProfiles.profile(for: app.bundleIdentifier ?? "")
        if profile.excluded || profile.readOnly || IsSecureEventInputEnabled() || AppState.shared.hotkeysPaused || AppState.shared.isDisabled(app.bundleIdentifier) { return }
        if profile.reader == .clipboard { AXTree.enable(app) }
        // only where Accessibility tells us what is selected and where it is on screen
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 0.2)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f,
              CFGetTypeID(f) == AXUIElementGetTypeID() else { return }
        let el = f as! AXUIElement
        if SelectionReader.stringAttr(el, kAXSubroleAttribute) == (kAXSecureTextFieldSubrole as String) { return }
        guard let t = SelectionReader.stringAttr(el, kAXSelectedTextAttribute),
              t.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
        var rv: CFTypeRef?; var cf = CFRange()
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &rv) == .success, let rv,
              CFGetTypeID(rv) == AXValueGetTypeID(), AXValueGetValue(rv as! AXValue, .cfRange, &cf), cf.length > 0,
              let rect = TextGeometry.bounds(el, NSRange(location: cf.location, length: cf.length)), rect.width > 0 else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        show(at: NSPoint(x: rect.minX - 8, y: primaryH - rect.maxY), app: app, keyboard: true)
    }

    /// Called by the key tap while the buttons are up after a keyboard selection. True = the key was ours.
    func handleKey(_ keyCode: Int, modifiers: CGEventFlags) -> Bool {
        guard keyboardMode, bubble != nil else { return false }
        if !modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty { return false }
        switch keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter: run(.polish); return true
        case kVK_Tab: run(.translate); return true
        case kVK_Escape: hide(); return true
        default: return false          // typing over the selection: the global monitor hides the buttons
        }
    }

    /// nil when the app gives no answer (no focused text element); otherwise whether text is selected.
    static func selectionState(pid: pid_t) -> Bool? {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.15)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f,
              CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(f as! AXUIElement, kAXSelectedTextAttribute as CFString, &v) == .success, let t = v as? String else { return nil }
        return t.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    /// Accessibility only, local, no clipboard: is there a non-trivial selection in the focused element?
    static func hasSelection(pid: pid_t) -> Bool {
        let appEl = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appEl, 0.1)
        var f: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &f) == .success, let f,
              CFGetTypeID(f) == AXUIElementGetTypeID() else { return false }
        let el = f as! AXUIElement
        if SelectionReader.stringAttr(el, kAXSubroleAttribute) == (kAXSecureTextFieldSubrole as String) { return false }
        guard let t = SelectionReader.stringAttr(el, kAXSelectedTextAttribute) else { return false }
        return t.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    // MARK: the button

    #if DEBUG
    /// QA: show the buttons in the middle of the screen so they can be photographed.
    func qaShow() { if let f = NSScreen.main?.frame { show(at: NSPoint(x: f.midX, y: f.midY), app: .current) } }
    var qaBubble: NSWindow? { bubble }
    func qaKeyboardSelection() { showForKeyboardSelection() }
    #endif

    private func show(at p: NSPoint, app: NSRunningApplication, keyboard: Bool = false) {
        hide()
        bubbleApp = app.processIdentifier
        keyboardMode = keyboard && KeyTap.shared.start()
        let view = BubbleView(keys: keyboardMode,
            fix: { [weak self] in self?.run(.fix) },
            polish: { [weak self] in self?.run(.polish) },
            translate: { [weak self] in self?.run(.translate) })
        let host = FirstClickHostingView(rootView: view)
        let size = host.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.contentView = host
        // just below-right of the pointer, kept on screen
        var origin = NSPoint(x: p.x + 8, y: p.y - size.height - 10)
        if let vf = NSScreen.screens.first(where: { $0.frame.contains(p) })?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            if origin.y < vf.minY + 4 { origin.y = p.y + 14 }
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        bubble = panel
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    func hide() {
        keyWork?.cancel(); keyWork = nil
        if keyboardMode {
            keyboardMode = false
            if !LiveChecker.shared.reviewing { KeyTap.shared.stop() }
        }
        hideWork?.cancel(); hideWork = nil
        bubble?.orderOut(nil)
        bubble = nil
    }

    private func run(_ op: TextOperation) {
        hide()
        // the source app is still in front (the button never activates GrammarBuddy): same path as the shortcut
        AppDelegate.shared?.hotkey(op)
    }
}

/// Takes the first click without becoming key, so the app that holds the selection keeps its focus.
private final class FirstClickHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct BubbleView: View {
    var keys = false
    var fix: () -> Void
    var polish: () -> Void
    var translate: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Two choices (user, 2026-11-19): "Fix" and "Polish" were one too many here. Polish corrects mistakes as
            // well; plain Fix is still the first tab inside the panel.
            button((keys ? "⏎ " : "") + L.t("润色", "Polish"), "wand.and.stars", polish)
            Divider().frame(height: 22)
            button((keys ? "⇥ " : "") + L.t("翻译", "Translate"), "character.bubble", translate)
            if keys { Text("Esc").font(.caption).foregroundStyle(.secondary).padding(.trailing, 8) }
        }
        .padding(.horizontal, 5).padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.quaternary))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GrammarBuddy")
    }

    func button(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.body.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 7).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title.hasSuffix(L.t("润色", "Polish")) ? L.t("改错并润色选中的文字", "Correct and polish the selected text") : title)
    }
}
