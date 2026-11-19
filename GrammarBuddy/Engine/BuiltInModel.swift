// BuiltInModel.swift
// The built-in model (design §7.7): runs inside GrammarBuddy with Apple's MLX, no LM Studio needed.
// - One click downloads the recommended model to ~/Library/Application Support/GrammarBuddy/Models/.
// - If LM Studio already downloaded the same model in MLX format, that folder is used directly (no second download).
// - Loaded on first use, unloaded after 10 idle minutes and when the system reports memory pressure.
// Thinking is switched off through the chat template (`enable_thinking: false`), as with LM Studio's reasoning:"off".

import Foundation
import Observation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
import GrammarBuddyKit

struct BuiltInChoice: Identifiable, Hashable {
    let id: String              // Hugging Face repo
    let name: String
    let sizeGB: Double
    let minRAM: Int
    let lmStudioFolder: String  // same weights as LM Studio downloads them
    let note: String

    static var catalog: [BuiltInChoice] {[
        BuiltInChoice(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit", name: "Qwen3 4B", sizeGB: 2.3, minRAM: 8,
                      lmStudioFolder: "lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit",
                      note: L.t("小而快，8–16 GB 内存的 Mac", "Small and fast, for 8–16 GB Macs")),
        BuiltInChoice(id: "mlx-community/Qwen3-14B-4bit", name: "Qwen3 14B", sizeGB: 8.3, minRAM: 24,
                      lmStudioFolder: "lmstudio-community/Qwen3-14B-MLX-4bit",
                      note: L.t("最准，24 GB 以上内存", "Most accurate, 24 GB+")),
    ]}

    /// docs/MODELS.md: 14B for 24 GB and up, otherwise 4B.
    static func recommended(ramGB: Int) -> BuiltInChoice { catalog.last { $0.minRAM <= max(8, ramGB) } ?? catalog[0] }
}

@MainActor
@Observable
final class BuiltInModels {
    static let shared = BuiltInModels()

    enum State: Equatable { case absent, downloading(Double?), ready, failed(String) }

    private(set) var states: [String: State] = [:]
    private(set) var loadedID: String?
    private var container: ModelContainer?
    private var idleTimer: Timer?
    private var pressureSource: DispatchSourceMemoryPressure?

    static var modelsDir: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GrammarBuddy/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private var hub: HubClient { HubClient(cache: HubCache(cacheDirectory: Self.modelsDir)) }

    init() {
        for c in BuiltInChoice.catalog { states[c.id] = localFolder(c) != nil || downloadedIDs.contains(c.id) ? .ready : .absent }
        watchMemoryPressure()
    }

    // MARK: where the weights are

    private var downloadedIDs: [String] {
        get { Store.defaults.stringArray(forKey: "gb_builtin_downloaded") ?? [] }
        set { Store.defaults.set(newValue, forKey: "gb_builtin_downloaded") }
    }

    /// LM Studio's MLX copy of the same model, if present and complete.
    func localFolder(_ c: BuiltInChoice) -> URL? {
        // QA: behave like a Mac that has never had LM Studio, to test the real first download
        if Store.defaults.bool(forKey: "gb_ignore_lmstudio_models") { return nil }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".lmstudio/models/" + c.lmStudioFolder)
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.appendingPathComponent("config.json").path),
              fm.fileExists(atPath: dir.appendingPathComponent("tokenizer.json").path),
              let files = try? fm.contentsOfDirectory(atPath: dir.path), files.contains(where: { $0.hasSuffix(".safetensors") })
        else { return nil }
        return dir
    }

    func choice(_ id: String) -> BuiltInChoice? { BuiltInChoice.catalog.first { $0.id == id } }
    func state(_ id: String) -> State { states[id] ?? .absent }
    func source(_ id: String) -> String {
        guard let c = choice(id) else { return "" }
        return localFolder(c) != nil ? L.t("使用 LM Studio 已下载的同一份模型，不用再下载", "Uses the copy LM Studio already downloaded; no second download")
                                     : L.t("存放在 ~/Library/Application Support/GrammarBuddy/Models", "Stored in ~/Library/Application Support/GrammarBuddy/Models")
    }

    // MARK: download (§7.7: size, progress, verified by loading)

    func download(_ id: String) async {
        guard let c = choice(id), state(id) != .ready else { return }
        if case .downloading = state(id) { return }
        states[id] = .downloading(nil)
        do {
            let hub = self.hub
            _ = try await loadModelContainer(from: #hubDownloader(hub), using: #huggingFaceTokenizerLoader(),
                                             configuration: ModelConfiguration(id: c.id, extraEOSTokens: ["<|im_end|>"])) { p in
                let f = p.totalUnitCount > 0 ? p.fractionCompleted : nil
                Task { @MainActor in BuiltInModels.shared.states[id] = .downloading(f) }
            }
            var d = downloadedIDs; if !d.contains(id) { d.append(id) }; downloadedIDs = d
            states[id] = .ready
            MLX.Memory.clearCache()
        } catch {
            states[id] = .failed(L.t("下载没有完成：", "The download didn't finish: ") + error.localizedDescription)
        }
    }

    /// Remove our own download (LM Studio's copy is never touched).
    func delete(_ id: String) {
        if loadedID == id { unload() }
        let folder = Self.modelsDir.appendingPathComponent("models--" + id.replacingOccurrences(of: "/", with: "--"))
        try? FileManager.default.removeItem(at: folder)
        downloadedIDs = downloadedIDs.filter { $0 != id }
        if let c = choice(id) { states[id] = localFolder(c) != nil ? .ready : .absent }
    }

    // MARK: load / unload

    func container(for id: String) async throws -> ModelContainer {
        if loadedID == id, let container { touch(); return container }
        unload()
        guard let c = choice(id) else { throw EngineError.noModel }
        let ctr: ModelContainer
        if let local = localFolder(c) {
            ctr = try await loadModelContainer(from: local, using: #huggingFaceTokenizerLoader())
        } else if downloadedIDs.contains(id) {
            let hub = self.hub
            ctr = try await loadModelContainer(from: #hubDownloader(hub), using: #huggingFaceTokenizerLoader(),
                                               configuration: ModelConfiguration(id: c.id, extraEOSTokens: ["<|im_end|>"]))
        } else {
            throw EngineError.server(L.t("内置模型还没有下载。到设置 → AI 里点一下「下载」。", "The built-in model isn't downloaded yet. Click Download in Settings → AI."))
        }
        container = ctr
        loadedID = id
        touch()
        return ctr
    }

    func unload() {
        container = nil
        loadedID = nil
        idleTimer?.invalidate(); idleTimer = nil
        MLX.Memory.clearCache()
    }

    private func touch() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { _ in
            Task { @MainActor in BuiltInModels.shared.unload() }        // 10 idle minutes (§7.7)
        }
    }

    private func watchMemoryPressure() {
        let src = DispatchSource.makeMemoryPressureSource(eventMask: [.critical], queue: .main)
        src.setEventHandler { Task { @MainActor in BuiltInModels.shared.unload() } }   // free memory at once (§7.7)
        src.resume()
        pressureSource = src
    }
}

/// Backend for the panel: same events as the HTTP backends.
struct BuiltInBackend: Backend {
    func models() async throws -> [ModelInfo] {
        await MainActor.run {
            BuiltInChoice.catalog.filter { BuiltInModels.shared.state($0.id) == .ready }
                .map { ModelInfo(id: $0.id, name: $0.name, loaded: BuiltInModels.shared.loadedID == $0.id, sizeBytes: Int64($0.sizeGB * 1e9)) }
        }
    }

    func run(_ req: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    let loaded = await MainActor.run { BuiltInModels.shared.loadedID == model }
                    if !loaded { cont.yield(.loadingModel) }
                    let container = try await BuiltInModels.shared.container(for: model)
                    let session = ChatSession(container, instructions: req.system,
                                              generateParameters: GenerateParameters(maxTokens: 4096, temperature: Float(req.temperature)),
                                              additionalContext: ["enable_thinking": false])
                    for try await chunk in session.streamResponse(to: req.text) {
                        try Task.checkCancellation()
                        if !chunk.isEmpty { cont.yield(.text(chunk)) }
                    }
                    cont.yield(.finished(.complete))
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}
