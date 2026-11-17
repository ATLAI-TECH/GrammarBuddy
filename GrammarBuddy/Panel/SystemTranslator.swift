// SystemTranslator.swift
// macOS system translation (design §7.6). On macOS 26 a session is created directly; language packs that are
// "supported but not installed" are downloaded from a normal window that hosts SwiftUI's .translationTask.

import AppKit
import SwiftUI
import Translation

enum TranslationState: Equatable { case ready, needsDownload, unsupported }

@MainActor
enum SystemTranslator {
    static func status(from: String, to: String) async -> TranslationState {
        let s = await LanguageAvailability().status(from: Locale.Language(identifier: from), to: Locale.Language(identifier: to))
        switch s {
        case .installed: return .ready
        case .supported: return .needsDownload
        default: return .unsupported
        }
    }

    /// Translate paragraph by paragraph in one batch (§2.7). Failed paragraphs come back as nil.
    static func translate(_ paragraphs: [String], from: String, to: String) async throws -> [String?] {
        guard #available(macOS 26.0, *) else {
            throw NSError(domain: "GrammarBuddy", code: 1, userInfo: [NSLocalizedDescriptionKey:
                L.t("macOS 15 上的系统翻译还没接通，请改用 AI 翻译", "System translation on macOS 15 isn't wired up yet; use AI translation")])
        }
        let session = TranslationSession(installedSource: Locale.Language(identifier: from), target: Locale.Language(identifier: to))
        let reqs = paragraphs.enumerated().map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
        let nonEmpty = reqs.filter { !$0.sourceText.trimmingCharacters(in: .whitespaces).isEmpty }
        var out = [String?](repeating: nil, count: paragraphs.count)
        for (i, p) in paragraphs.enumerated() where p.trimmingCharacters(in: .whitespaces).isEmpty { out[i] = p }
        let res = try await session.translations(from: nonEmpty)
        for r in res { if let id = r.clientIdentifier, let i = Int(id) { out[i] = r.targetText } }
        return out
    }

    // MARK: language pack download in its own normal window (§7.6)

    private static var window: NSWindow?

    static func download(from: String, to: String, done: @escaping @MainActor (Bool) -> Void) {
        let view = DownloadHost(from: from, to: to) { ok in
            window?.close(); window = nil
            done(ok)
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 160), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L.t("下载语言包", "Download languages")
        w.contentView = NSHostingView(rootView: view)
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    struct DownloadHost: View {
        let from: String, to: String
        let done: (Bool) -> Void
        @State private var config: TranslationSession.Configuration?
        @State private var status = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("第一次翻译 \(name(from)) → \(name(to)) 需要下载系统的语言包。下载后翻译在这台 Mac 上完成。",
                         "Translating \(name(from)) → \(name(to)) needs a one-time system language download. After that, translation runs on this Mac."))
                    .fixedSize(horizontal: false, vertical: true)
                Text(status).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button(L.t("取消", "Cancel")) { done(false) }.keyboardShortcut(.cancelAction)
                    Button(L.t("下载", "Download")) {
                        status = L.t("请在系统弹出的窗口里确认下载…", "Confirm the download in the system sheet…")
                        config = TranslationSession.Configuration(source: Locale.Language(identifier: from), target: Locale.Language(identifier: to))
                    }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420)
            .translationTask(config) { session in
                do {
                    try await session.prepareTranslation()
                    await MainActor.run { done(true) }
                } catch {
                    await MainActor.run { status = L.t("没有下载：", "Not downloaded: ") + error.localizedDescription }
                }
            }
        }

        func name(_ c: String) -> String { LanguageDirection.displayName(c) }
    }
}

import GrammarBuddyKit
