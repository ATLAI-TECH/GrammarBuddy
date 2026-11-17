// AppProfiles.swift
// The single source of per-app behaviour (design §4.6). Users can override entries in Settings.

import Foundation

public struct AppProfile: Sendable, Equatable {
    public enum Reader: String, Sendable { case auto, clipboard, word }
    public enum Writer: String, Sendable { case auto, axWhole, paste, none }

    public var excluded = false
    public var readOnly = false
    public var reader: Reader = .auto
    public var writer: Writer = .auto
    public var richText: RichText? = nil
    public var assumeEditable = false
    public var emptyCopyCopiesLine = false
    public var localOnly = false            // §7.4 "only use the local model in these apps"

    public init() {}
}

public enum AppProfiles {
    public static let excluded: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.apple.keychainaccess",
        "org.keepassxc.keepassxc", "com.dashlane.dashlanephonefinal", "com.lastpass.LastPass", "com.apple.Passwords",
    ]
    public static let readOnly: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "com.github.wez.wezterm", "org.alacritty", "dev.warp.Warp-Stable",
    ]
    /// Chromium / Electron apps do not expose an accessibility tree by default (§5.1).
    public static let clipboardReaders: Set<String> = [
        "com.google.Chrome", "com.tinyspeck.slackmacgap", "com.microsoft.VSCode", "notion.id", "md.obsidian",
        "com.linear", "com.tencent.xinWeChat", "com.microsoft.edgemac", "company.thebrowser.Browser",
    ]
    public static let plainText: Set<String> = ["com.microsoft.VSCode", "md.obsidian", "com.apple.dt.Xcode"]
    public static let copiesLine: Set<String> = ["com.microsoft.VSCode", "md.obsidian"]
    public static let word = "com.microsoft.Word"

    public static func profile(for bundleID: String, overrides: [String: AppProfile] = [:]) -> AppProfile {
        if let o = overrides[bundleID] { return o }
        var p = AppProfile()
        p.excluded = excluded.contains(bundleID)
        p.readOnly = readOnly.contains(bundleID)
        if bundleID == word { p.reader = .word }
        else if clipboardReaders.contains(bundleID) { p.reader = .clipboard; p.writer = .paste }
        if plainText.contains(bundleID) { p.richText = .plain }
        p.emptyCopyCopiesLine = copiesLine.contains(bundleID)
        return p
    }
}
