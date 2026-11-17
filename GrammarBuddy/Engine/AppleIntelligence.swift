// AppleIntelligence.swift
// Apple's on-device model through FoundationModels (design §7.1). Offered only when the Mac supports it and it's on.

import Foundation
import FoundationModels
import GrammarBuddyKit

enum AppleIntelligence {
    enum Status: Equatable { case available, notEnabled, notSupported, managedOff, notReady }

    static var status: Status {
        guard #available(macOS 26.0, *) else { return .notSupported }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
        case .unavailable(.deviceNotEligible): return .notSupported
        case .unavailable(.modelNotReady): return .notReady
        default: return .managedOff
        }
    }

    static var statusText: String {
        switch status {
        case .available: return L.t("可以用", "Available")
        case .notEnabled: return L.t("这台 Mac 支持，但还没有开启：系统设置 → Apple 智能与 Siri", "Supported but off: System Settings → Apple Intelligence & Siri")
        case .notSupported: return L.t("这台 Mac 或系统版本不支持", "Not supported on this Mac or macOS version")
        case .notReady: return L.t("模型还在下载，稍后再试", "The model is still downloading; try later")
        case .managedOff: return L.t("这台 Mac 的管理员关闭了它", "Turned off by this Mac's administrator")
        }
    }
}

struct AppleIntelligenceBackend: Backend {
    func models() async throws -> [ModelInfo] {
        AppleIntelligence.status == .available ? [ModelInfo(id: "apple", name: "Apple Intelligence", loaded: true, sizeBytes: 0)] : []
    }

    func run(_ req: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                guard #available(macOS 26.0, *), AppleIntelligence.status == .available else {
                    cont.finish(throwing: EngineError.server("Apple Intelligence: " + AppleIntelligence.statusText)); return
                }
                do {
                    let session = LanguageModelSession(instructions: req.system)
                    var sent = ""
                    for try await snapshot in session.streamResponse(to: req.text, options: GenerationOptions(temperature: req.temperature)) {
                        try Task.checkCancellation()
                        let full = snapshot.content
                        if full.count > sent.count, full.hasPrefix(sent) { cont.yield(.text(String(full.dropFirst(sent.count)))) }
                        sent = full
                    }
                    cont.yield(.finished(.complete))
                    cont.finish()
                } catch { cont.finish(throwing: error) }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}

/// The one place that turns an engine setting into a backend (HTTP ones come from the Kit).
enum Engines {
    @MainActor static func backend(for e: EngineConfig) -> Backend {
        switch e.kind {
        case .builtin: return BuiltInBackend()
        case .apple: return AppleIntelligenceBackend()
        default: return BackendFactory.make(e, key: e.keychainAccount.flatMap { Keychain.get(account: $0) })
        }
    }
}
