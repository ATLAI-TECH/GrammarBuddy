// AppDelegate.swift
// Menu-bar app: status item, global shortcuts, the read → panel flow (design §2.1, §2.11, §4.4).

import AppKit
import SwiftUI
import GrammarBuddyKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static weak var shared: AppDelegate?
    let state = AppState.shared
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var testWindow: NSWindow?
    var settingsTab = SettingsTab.general
    private var readingHint: NSPanel?

    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.accessory)
        // K5-11: an Edit menu so ⌘Z / ⌘C / ⌘V / ⌘A work in our own windows (onboarding, settings, test window)
        let main = NSMenu(), appItem = NSMenuItem(), editItem = NSMenuItem()
        main.addItem(appItem); main.addItem(editItem)
        appItem.submenu = NSMenu()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z"); redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        app.mainMenu = main
        app.run()
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        AppDelegate.shared = self
        QAHarness.shared.startIfRequested()
        if state.myLanguages.count < 2 { state.myLanguages = state.defaultLanguages() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        registerHotkeys()
        SelectionWatcher.shared.start()
        LiveChecker.shared.start()           // underline mistakes in place (off unless enabled in Settings)      // select text → a small Fix / Translate button
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in self?.frontAppChanged(app) }
        }
        if !state.onboardingDone && !QAHarness.shared.suppressOnboarding { openOnboarding() }
        else if !QAHarness.shared.suppressOnboarding {
            // a menu-bar app shows no window: say where it is (the icon can hide behind the notch)
            Toast.show(L.t("GrammarBuddy 已在菜单栏运行。选中文字按 ⌃⌘G 改错、⌃⌘T 翻译", "GrammarBuddy is running in the menu bar. Select text and press ⌃⌘G to fix, ⌃⌘T to translate"))
        }
    }

    /// Double-clicking the app (or `open`) while it runs: show something instead of nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !state.onboardingDone { openOnboarding() } else { openSettings(tab: .general) }
        return false
    }

    func updateIcon() {
        let name = state.hotkeyProblem != nil ? "exclamationmark.bubble"
            : (state.hotkeysPaused ? "pause.circle" : (LiveChecker.shared.isBusy ? "ellipsis.bubble" : "text.bubble"))
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "GrammarBuddy")
        statusItem.button?.toolTip = state.hotkeyProblem ?? "GrammarBuddy"
    }

    // MARK: shortcuts (§2.1)

    func registerHotkeys() {
        let failed = HotKeys.shared.register([
            (1, HotKeys.fix, { [weak self] in self?.hotkey(.fix) }),
            (2, HotKeys.translate, { [weak self] in self?.hotkey(.translate) }),
            (3, HotKeys.nextSuggestion, { LiveChecker.shared.reviewNext() }),
        ])
        state.hotkeyProblem = failed.isEmpty ? nil : L.t("快捷键 \(failed.joined(separator: "、")) 被别的 App 占用了", "Shortcut \(failed.joined(separator: ", ")) is taken by another app")
        updateIcon()
    }

    /// Shortcuts are unregistered while an excluded app (password manager) is in front (§2.1).
    func frontAppChanged(_ app: NSRunningApplication?) {
        let excluded = AppProfiles.profile(for: app?.bundleIdentifier ?? "").excluded
        if excluded || state.hotkeysPaused { HotKeys.shared.unregisterAll() } else { registerHotkeys() }
    }

    func hotkey(_ op: TextOperation) {
        let pc = PanelController.shared
        // our own windows: read in-process (onboarding demo, test window)
        if let key = NSApp.keyWindow, key !== pc.panel, let tv = key.firstResponder as? NSTextView {
            openInProcess(tv, op: op)
            return
        }
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        if pc.isOpen, pc.sourcePID == front.processIdentifier {
            // same app: bring the panel back; if it's already in front, the second press starts over (§2.1)
            if pc.panel?.isKeyWindow != true { pc.bringBack(); return }
            if !secondPressArmed { secondPressArmed = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.secondPressArmed = false }; return }
        }
        secondPressArmed = false
        if pc.isOpen { pc.close() }
        Task { await read(front: front, op: op) }
    }
    private var secondPressArmed = false

    func read(front: NSRunningApplication, op: TextOperation) async {
        let hint = DispatchWorkItem { [weak self] in self?.showReadingHint() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: hint)     // §4.4: 150 ms
        let res = await SelectionReader.read(app: front)
        hint.cancel(); hideReadingHint()
        switch res {
        case .success(let o): PanelController.shared.show(outcome: o, failure: nil, operation: op, app: front)
        case .failure(let f): PanelController.shared.show(outcome: nil, failure: f, operation: op, app: front)
        }
    }

    func openInProcess(_ tv: NSTextView, op: TextOperation) {
        let r = tv.selectedRange()
        let text = (tv.string as NSString).substring(with: r)
        let me = NSRunningApplication.current
        guard r.length > 0, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {   // T5-13
            PanelController.shared.show(outcome: nil, failure: .noSelection, operation: op, app: me); return
        }
        var cap = Capture(raw: text, via: .accessibility, editability: tv.isEditable ? .editable : .readOnly,
                          richText: Self.richness(tv, r), range: r,
                          app: TargetApp(bundleID: Bundle.main.bundleIdentifier ?? "atlai.GrammarBuddy", name: "GrammarBuddy", pid: me.processIdentifier))
        cap.range = r
        var h = WriteHandle(pid: me.processIdentifier)
        h.inProcess = tv
        var bounds: CGRect?
        if let lm = tv.layoutManager, let tc = tv.textContainer, let w = tv.window {
            let g = lm.glyphRange(forCharacterRange: r, actualCharacterRange: nil)
            let rect = tv.convert(lm.boundingRect(forGlyphRange: g, in: tc), to: nil)
            let sr = w.convertToScreen(rect)
            let primaryH = NSScreen.screens.first?.frame.height ?? 0
            bounds = CGRect(x: sr.minX, y: primaryH - sr.maxY, width: sr.width, height: sr.height)
        }
        PanelController.shared.show(outcome: ReadOutcome(capture: cap, handle: h, bounds: bounds, windowFrame: nil), failure: nil, operation: op, app: me)
    }

    /// Our own text views know their formatting: plain unless the selection has links or more than one font (L5-02).
    static func richness(_ tv: NSTextView, _ r: NSRange) -> RichText {
        guard tv.isRichText, let ts = tv.textStorage, r.length > 0 else { return .plain }
        var fonts = Set<String>(), link = false
        ts.enumerateAttributes(in: r) { a, _, _ in
            if let f = a[.font] as? NSFont { fonts.insert(f.fontName + "\(f.pointSize)") }
            if a[.link] != nil { link = true }
        }
        return link || fonts.count > 1 ? .rich : .plain
    }

    func showReadingHint() {
        let v = NSHostingView(rootView: Text(L.t("正在读取…", "Reading…")).font(.callout).padding(.horizontal, 12).padding(.vertical, 6).background(.regularMaterial, in: Capsule()))
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: v.fittingSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.level = .statusBar; p.ignoresMouseEvents = true; p.contentView = v
        let m = NSEvent.mouseLocation
        p.setFrameOrigin(NSPoint(x: m.x + 12, y: m.y - 30))
        p.orderFrontRegardless()
        readingHint = p
    }
    func hideReadingHint() { readingHint?.orderOut(nil); readingHint = nil }

    // MARK: menu (§2.11)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let p = state.hotkeyProblem {
            let i = NSMenuItem(title: p, action: #selector(openGeneralSettings), keyEquivalent: ""); i.target = self; menu.addItem(i)
            menu.addItem(.separator())
        }
        if PanelController.shared.panel != nil {
            add(menu, L.t("回到面板", "Back to the panel"), #selector(backToPanel))
        }
        add(menu, L.t("改错选中的文字  ⌃⌘G", "Fix selected text  ⌃⌘G"), #selector(menuFix))
        add(menu, L.t("翻译选中的文字  ⌃⌘T", "Translate selected text  ⌃⌘T"), #selector(menuTranslate))
        menu.addItem(.separator())
        let h = NSMenuItem(title: L.t("最近的记录", "Recent"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if state.history.isEmpty {
            sub.addItem(NSMenuItem(title: state.historyEnabled ? L.t("还没有记录", "Nothing yet") : L.t("历史记录已关闭", "History is off"), action: nil, keyEquivalent: ""))
        }
        let f = DateFormatter(); f.timeStyle = .short
        for item in state.history.prefix(5) {
            let row = NSMenuItem(title: "\(OpNames.name(item.operation)) · \(item.appName) · \(f.string(from: item.date))", action: nil, keyEquivalent: "")
            let s2 = NSMenu()
            let cr = NSMenuItem(title: L.t("复制结果", "Copy result"), action: #selector(copyHistory(_:)), keyEquivalent: ""); cr.target = self; cr.representedObject = item.result
            let co = NSMenuItem(title: L.t("复制原文", "Copy original"), action: #selector(copyHistory(_:)), keyEquivalent: ""); co.target = self; co.representedObject = item.original
            s2.addItem(cr); s2.addItem(co)
            row.submenu = s2
            sub.addItem(row)
        }
        h.submenu = sub
        menu.addItem(h)
        let live = NSMenuItem(title: L.t("实时标记错误（只用本机模型）", "Live check (local model only)"), action: #selector(toggleLive), keyEquivalent: "")
        live.target = self; live.state = LiveChecker.shared.enabled ? .on : .off; menu.addItem(live)
        let pause = NSMenuItem(title: state.hotkeysPaused ? L.t("恢复快捷键", "Resume shortcuts") : L.t("暂停快捷键", "Pause shortcuts"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self; menu.addItem(pause)
        if !state.history.isEmpty { add(menu, L.t("清空历史", "Clear history"), #selector(clearHistory)) }   // G5-14
        menu.addItem(.separator())
        add(menu, L.t("设置…", "Settings…"), #selector(openGeneralSettings), key: ",")
        add(menu, L.t("引导…", "Setup guide…"), #selector(openOnboardingAction))
        add(menu, L.t("测试窗口…", "Test window…"), #selector(openTestWindow))
        #if DEBUG
        add(menu, L.t("M0 探针：3 秒后探测前台 App", "M0 probe: probe the front app in 3 s"), #selector(runProbe))
        #endif
        menu.addItem(.separator())
        add(menu, L.t("退出 GrammarBuddy", "Quit GrammarBuddy"), #selector(quit), key: "q")
    }

    private func add(_ menu: NSMenu, _ title: String, _ sel: Selector, key: String = "") {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key); i.target = self; menu.addItem(i)
    }

    @objc func backToPanel() { PanelController.shared.bringBack() }
    @objc func menuFix() { hotkey(.fix) }
    @objc func menuTranslate() { hotkey(.translate) }
    @objc func copyHistory(_ s: NSMenuItem) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s.representedObject as? String ?? "", forType: .string)
    }
    @objc func togglePause() {
        state.hotkeysPaused.toggle()
        if state.hotkeysPaused { HotKeys.shared.unregisterAll() } else { registerHotkeys() }
        updateIcon()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleLive() { LiveChecker.shared.enabled.toggle() }
    @objc func clearHistory() { state.history.removeAll() }
    #if DEBUG
    @objc func runProbe() { Probe.runSoon() }
    #endif
    @objc func openGeneralSettings() { openSettings(tab: .general) }
    @objc func openOnboardingAction() { openOnboarding() }

    // MARK: windows

    func openSettings(tab: SettingsTab) {
        settingsTab = tab
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = L.t("GrammarBuddy 设置", "GrammarBuddy Settings")
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(selection: tab))
            w.center()
            settingsWindow = w
        } else {
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView(selection: tab))
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func openOnboarding() {
        let w = onboardingWindow ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L.t("欢迎使用 GrammarBuddy", "Welcome to GrammarBuddy")
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView(close: { [weak self] in self?.onboardingWindow?.close() }))
        w.center()
        onboardingWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    /// §9: our own window with plain and rich text views, for trying read / write / undo.
    @objc func openTestWindow() {
        let w = testWindow ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 420), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = L.t("GrammarBuddy 测试窗口", "GrammarBuddy test window")
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: TestWindowView())
        w.center()
        testWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
