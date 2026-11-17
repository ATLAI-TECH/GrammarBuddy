// L10n.swift
// Interface language: English or Simplified Chinese (design §2.11). Strings are written inline in pairs.

import Foundation

/// Settings store. QA instances get their own suite so several can run side by side (GrammarBuddy/QA).
public enum Store {
    nonisolated(unsafe) public static var defaults: UserDefaults = .standard
}

public enum L {
    public static let key = "gb_ui_language"   // "zh" | "en" | "" (follow the system)

    public static var isChinese: Bool {
        let v = Store.defaults.string(forKey: key) ?? ""
        if v == "zh" { return true }
        if v == "en" { return false }
        return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    public static func t(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
}
