// HotKey.swift
// Global shortcuts with Carbon RegisterEventHotKey: no accessibility permission needed (design §4.2).
// Registration failures are reported so the menu-bar icon can show a dot (§2.1).

import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeys {
    static let shared = HotKeys()
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var installed = false

    struct Combo { var keyCode: UInt32; var modifiers: UInt32; var label: String }
    static let fix = Combo(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(controlKey | cmdKey), label: "⌃⌘G")
    static let nextSuggestion = Combo(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(controlKey | cmdKey), label: "⌃⌘J")
    static let translate = Combo(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | cmdKey), label: "⌃⌘T")

    /// Returns the labels that failed to register.
    @discardableResult
    func register(_ list: [(UInt32, Combo, () -> Void)]) -> [String] {
        installHandler()
        unregisterAll()
        var failed: [String] = []
        for (id, combo, handler) in list {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4742_4459), id: id)   // 'GBDY'
            let st = RegisterEventHotKey(combo.keyCode, combo.modifiers, hkID, GetEventDispatcherTarget(), 0, &ref)
            if st == noErr, let ref { refs[id] = ref; handlers[id] = handler } else { failed.append(combo.label) }
        }
        return failed
    }

    func unregisterAll() {
        for r in refs.values { UnregisterEventHotKey(r) }
        refs.removeAll()
    }

    func fire(_ id: UInt32) { handlers[id]?() }

    private func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            Task { @MainActor in HotKeys.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
