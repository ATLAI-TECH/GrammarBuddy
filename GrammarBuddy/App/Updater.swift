// Updater.swift
// Automatic updates with Sparkle. Once a day the app fetches a small feed (appcast.xml, an asset of the newest
// GitHub Release) and, if there is a newer version, offers it in Sparkle's standard window; the download is checked
// against the public key in Info.plist before anything is installed. Nothing about the user or their text is sent:
// the request is a plain download of the feed.

import AppKit
import Sparkle
import GrammarBuddyKit

@MainActor
final class Updater: NSObject, SPUUpdaterDelegate {
    static let shared = Updater()
    private var controller: SPUStandardUpdaterController!
    private(set) var lastEvent = ""          // for the QA dump: what the last check found

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    }

    func start() {}                           // touching `shared` starts the updater and its daily schedule

    var automaticChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    var automaticDownloads: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    /// The menu item: shows Sparkle's window whether or not there is an update.
    @objc func checkNow() {
        NSApp.activate(ignoringOtherApps: true)      // a menu-bar app has no front window for Sparkle to attach to
        controller.checkForUpdates(nil)
    }

    /// Without a window: used by tests.
    func checkInBackground() { controller.updater.checkForUpdatesInBackground() }

    // MARK: SPUUpdaterDelegate

    #if DEBUG
    /// Tests point a debug build at a local feed.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? { Store.defaults.string(forKey: "gb_feed_url") }
    #endif
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let v = item.displayVersionString
        Task { @MainActor in self.lastEvent = "found \(v)" }
    }
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) { Task { @MainActor in self.lastEvent = "up to date" } }
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let m = error.localizedDescription
        Task { @MainActor in if !self.lastEvent.hasPrefix("found") { self.lastEvent = "error: \(m)" } }
    }
    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) { Task { @MainActor in self.lastEvent = "downloaded \(item.displayVersionString)" } }
    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) -> Bool {
        Task { @MainActor in self.lastEvent = "ready to install \(item.displayVersionString) on quit" }
        return false
    }
}
