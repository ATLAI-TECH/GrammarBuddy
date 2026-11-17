// AppState.swift
// Settings and shared state (design §2.11). Stored in UserDefaults; API keys in the Keychain.

import AppKit
import Carbon.HIToolbox
import GrammarBuddyKit
import Observation

struct HistoryItem: Identifiable {
    let id = UUID()
    let date = Date()
    let operation: TextOperation
    let original: String
    let result: String
    let appName: String
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    private var d: UserDefaults { Store.defaults }

    // MARK: languages (§2.5)
    var myLanguages: [String] {
        get { access(keyPath: \.myLanguages); return d.stringArray(forKey: "gb_languages") ?? [] }
        set { withMutation(keyPath: \.myLanguages) { d.set(newValue, forKey: "gb_languages") } }
    }
    var lastTargets: [String: String] {
        get { access(keyPath: \.lastTargets); return d.dictionary(forKey: "gb_last_targets") as? [String: String] ?? [:] }
        set { withMutation(keyPath: \.lastTargets) { d.set(newValue, forKey: "gb_last_targets") } }
    }
    var translateWithAI: Bool {
        get { access(keyPath: \.translateWithAI); return d.bool(forKey: "gb_translate_ai") }
        set { withMutation(keyPath: \.translateWithAI) { d.set(newValue, forKey: "gb_translate_ai") } }
    }
    var joinHardWraps: Bool {
        get { access(keyPath: \.joinHardWraps); return d.object(forKey: "gb_join_wraps") as? Bool ?? true }
        set { withMutation(keyPath: \.joinHardWraps) { d.set(newValue, forKey: "gb_join_wraps") } }
    }

    // MARK: writing (§2.11)
    var protectedWords: [String] {
        get { access(keyPath: \.protectedWords); return d.stringArray(forKey: "gb_protected") ?? [] }
        set { withMutation(keyPath: \.protectedWords) { d.set(newValue, forKey: "gb_protected") } }
    }
    var lastTone: Tone? {
        get { access(keyPath: \.lastTone); return d.string(forKey: "gb_tone").flatMap(Tone.init(rawValue:)) }
        set { withMutation(keyPath: \.lastTone) { d.set(newValue?.rawValue, forKey: "gb_tone") } }
    }

    // MARK: engines (§7)
    var engines: [EngineConfig] {
        get {
            access(keyPath: \.engines)
            guard let data = d.data(forKey: "gb_engines"), let e = try? JSONDecoder().decode([EngineConfig].self, from: data) else { return [] }
            return e
        }
        set { withMutation(keyPath: \.engines) { d.set(try? JSONEncoder().encode(newValue), forKey: "gb_engines") } }
    }
    var activeEngineID: String? {
        get { access(keyPath: \.activeEngineID); return d.string(forKey: "gb_active_engine") }
        set { withMutation(keyPath: \.activeEngineID) { d.set(newValue, forKey: "gb_active_engine") } }
    }
    var activeEngine: EngineConfig? { engines.first { $0.id == activeEngineID } ?? engines.first }
    /// The engine used where text must stay on this Mac (§7.4 safeguard 3): built-in first, then Apple, LM Studio, Ollama.
    var localEngine: EngineConfig? { engines.first { $0.kind.isLocal } }

    /// §7.4 safeguard 2: per-app permission to send to an API, keyed "engineID|bundleID"
    var apiAllowedApps: [String: Bool] {
        get { access(keyPath: \.apiAllowedApps); return d.dictionary(forKey: "gb_api_allowed") as? [String: Bool] ?? [:] }
        set { withMutation(keyPath: \.apiAllowedApps) { d.set(newValue, forKey: "gb_api_allowed") } }
    }
    /// §2.4 assumeEditable, confirmed by the user per app; and apps waiting for that question
    var assumeEditableApps: [String] {
        get { access(keyPath: \.assumeEditableApps); return d.stringArray(forKey: "gb_assume_editable") ?? [] }
        set { withMutation(keyPath: \.assumeEditableApps) { d.set(newValue, forKey: "gb_assume_editable") } }
    }
    var askAssumeEditable: [String] {
        get { access(keyPath: \.askAssumeEditable); return d.stringArray(forKey: "gb_ask_assume_editable") ?? [] }
        set { withMutation(keyPath: \.askAssumeEditable) { d.set(newValue, forKey: "gb_ask_assume_editable") } }
    }

    /// §7.4 safeguard 3: apps where only the local model is used
    var localOnlyApps: [String] {
        get { access(keyPath: \.localOnlyApps); return d.stringArray(forKey: "gb_local_only") ?? [] }
        set { withMutation(keyPath: \.localOnlyApps) { d.set(newValue, forKey: "gb_local_only") } }
    }

    // MARK: privacy (§2.11, §8)
    var historyEnabled: Bool {
        get { access(keyPath: \.historyEnabled); return d.object(forKey: "gb_history") as? Bool ?? true }
        set { withMutation(keyPath: \.historyEnabled) { d.set(newValue, forKey: "gb_history"); if !newValue { history.removeAll() } } }
    }
    var neverUseClipboard: Bool {
        get { access(keyPath: \.neverUseClipboard); return d.bool(forKey: "gb_never_clipboard") }
        set { withMutation(keyPath: \.neverUseClipboard) { d.set(newValue, forKey: "gb_never_clipboard") } }
    }
    var onboardingDone: Bool {
        get { access(keyPath: \.onboardingDone); return d.bool(forKey: "gb_onboarded") }
        set { withMutation(keyPath: \.onboardingDone) { d.set(newValue, forKey: "gb_onboarded") } }
    }
    var uiLanguage: String {
        get { access(keyPath: \.uiLanguage); return d.string(forKey: L.key) ?? "" }
        set { withMutation(keyPath: \.uiLanguage) { d.set(newValue, forKey: L.key) } }
    }
    var hotkeysPaused = false
    var hotkeyProblem: String?

    /// In memory only, last 20, never written to disk (§8).
    var history: [HistoryItem] = []
    func remember(_ item: HistoryItem) {
        guard historyEnabled else { return }
        history.insert(item, at: 0)
        if history.count > 20 { history.removeLast(history.count - 20) }
    }

    static func inputMethodLanguages() -> [String] {
        guard let list = TISCreateInputSourceList([kTISPropertyInputSourceIsEnabled as String: true] as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else { return [] }
        var out: [String] = []
        for src in list {
            guard let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) else { continue }
            let langs = Unmanaged<CFArray>.fromOpaque(p).takeUnretainedValue() as? [String] ?? []
            if let first = langs.first {
                let b = LanguageDirectionHelpers.base(first)
                let type = TISGetInputSourceProperty(src, kTISPropertyInputSourceType).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
                if type == (kTISTypeKeyboardInputMode as String) || type == (kTISTypeKeyboardInputMethodModeEnabled as String) || type == (kTISTypeKeyboardInputMethodWithoutModes as String),
                   !out.contains(b) { out.append(b) }
            }
        }
        return out
    }

    var ramGB: Int { Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded()) }

    /// Default "my languages" from the system language and enabled input methods (§2.10 step 1).
    func defaultLanguages() -> [String] {
        let sys = Locale.preferredLanguages.map { LanguageDirectionHelpers.base($0) }
        var out: [String] = []
        // §2.10 / L5-11: a non-English input method (pinyin, kana…) is a strong hint for the native language
        for l in Self.inputMethodLanguages() where l != "en" && !out.contains(l) { out.append(l) }
        for l in sys where !out.contains(l) { out.append(l) }
        if !out.contains("en") { out.append("en") }
        if out.count == 1 { out.append(out[0] == "en" ? "zh-Hans" : "en") }
        return Array(out.prefix(2))
    }
}

enum LanguageDirectionHelpers {
    static func base(_ code: String) -> String {
        if code.hasPrefix("zh") { return code.contains("Hant") || code.contains("TW") || code.contains("HK") ? "zh-Hant" : "zh-Hans" }
        return String(code.split(separator: "-").first ?? Substring(code))
    }
    static let choices = ["en", "zh-Hans", "zh-Hant", "es", "fr", "de", "ja", "ko", "pt", "it", "ru", "ar", "nl", "pl", "tr", "vi", "th", "id", "uk", "hi"]
}
