// EngineSetup.swift
// Shared by onboarding step 4 and Settings → AI (design §2.10, §7.2, §7.3).

import SwiftUI
import GrammarBuddyKit

@MainActor
@Observable
final class EngineSetup {
    let state = AppState.shared
    // API
    var service: APIService = APIService.all[0]
    var customURL = ""
    var apiKey = ""
    var apiModels: [ModelInfo] = []
    var apiModel = ""
    var apiStatus: String?
    var apiOK = false
    var testing = false
    // local
    var lmRunning: Bool?
    var lmInstalled = false
    var ollamaRunning = false
    var localModels: [ModelInfo] = []
    var localModel = ""
    var localKind: EngineKind = .lmstudio
    var download: (key: String, fraction: Double?)?
    var localStatus: String?
    // built-in (MLX)
    var builtInModel = ""

    /// Replace the engine with the same id, keep the others (built-in, LM Studio / Ollama, API can all coexist).
    func upsert(_ e: EngineConfig, makeActive: Bool = false) {
        var es = state.engines.filter { $0.id != e.id }
        es.append(e)
        es.sort { order($0.kind) < order($1.kind) }
        state.engines = es
        if makeActive || state.activeEngineID == nil || !es.contains(where: { $0.id == state.activeEngineID }) { state.activeEngineID = e.id }
    }
    private func order(_ k: EngineKind) -> Int { [.builtin, .apple, .lmstudio, .ollama, .api, .anthropic].firstIndex(of: k) ?? 9 }

    func saveBuiltIn() {
        guard let c = BuiltInModels.shared.choice(builtInModel) else { return }
        upsert(EngineConfig(id: "builtin", kind: .builtin, name: L.t("内置", "Built-in"), baseURL: "builtin:mlx", model: c.id), makeActive: true)
    }

    func saveApple() {
        upsert(EngineConfig(id: "apple", kind: .apple, name: "Apple Intelligence", baseURL: "apple:foundation", model: "apple"))
    }

    init() {
        if let api = state.engines.first(where: { $0.kind == .api || $0.kind == .anthropic }) {
            service = APIService.all.first { $0.baseURL == api.baseURL } ?? APIService.all.last!
            if service.id == "custom" { customURL = api.baseURL }
            apiModel = api.model
            apiKey = api.keychainAccount.flatMap { Keychain.get(account: $0) } ?? ""
            apiOK = !apiKey.isEmpty
        }
        if let l = state.engines.first(where: { $0.kind == .lmstudio || $0.kind == .ollama }) { localModel = l.model; localKind = l.kind }
        builtInModel = state.engines.first(where: { $0.kind == .builtin })?.model ?? BuiltInChoice.recommended(ramGB: state.ramGB).id
    }

    var apiBase: String { service.id == "custom" ? customURL.trimmingCharacters(in: .whitespaces) : service.baseURL }

    func testAPI() async {
        testing = true; apiStatus = nil; apiOK = false
        defer { testing = false }
        let base = apiBase
        guard !base.isEmpty else { apiStatus = L.t("请填写接口地址", "Enter the API address"); return }
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { apiStatus = L.t("请粘贴 API key", "Paste an API key"); return }
        do {
            let key = apiKey.trimmingCharacters(in: .whitespaces)
            let ms = service.kind == .anthropic ? try await AnthropicBackend(base: base, key: key).models()
                                                : try await OpenAICompatibleBackend(base: base, key: key, displayName: service.name).models()
            apiModels = ms
            if !ms.contains(where: { $0.id == apiModel }) { apiModel = preferredAPIModel(ms) }
            apiOK = true
            apiStatus = L.t("连接成功，有 \(ms.count) 个模型。", "Connected. \(ms.count) models available.")
        } catch let e as EngineError {
            apiStatus = e.message
        } catch {
            apiStatus = error.localizedDescription
        }
    }

    func preferredAPIModel(_ ms: [ModelInfo]) -> String {
        for p in ["gpt-4.1-mini", "gpt-4o-mini", "claude-haiku-4-5", "gemini-2.5-flash", "deepseek-chat", "openai/gpt-4.1-mini", "Qwen/Qwen3-8B"] where ms.contains(where: { $0.id == p }) { return p }
        return ms.first?.id ?? ""
    }

    func saveAPI() {
        let account = "api-" + (service.id == "custom" ? (URL(string: apiBase)?.host ?? "custom") : service.id)
        Keychain.set(apiKey.trimmingCharacters(in: .whitespaces), account: account)
        upsert(EngineConfig(id: "api", kind: service.kind, name: service.id == "custom" ? (URL(string: apiBase)?.host ?? "API") : service.name,
                            baseURL: apiBase, model: apiModel, keychainAccount: account))
    }

    func removeAPI() {
        state.engines = state.engines.filter { $0.id != "api" }
        if state.activeEngineID == "api" { state.activeEngineID = state.engines.first?.id }
        apiOK = false
    }

    // MARK: local

    func refreshLocal() async {
        lmInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "ai.elementlabs.lmstudio") != nil
            || FileManager.default.fileExists(atPath: "/Applications/LM Studio.app")
        if let ms = try? await LMStudioBackend(base: "http://localhost:1234").models() {
            lmRunning = true; localModels = ms; localKind = .lmstudio
        } else {
            lmRunning = false
            if let ms = try? await OpenAICompatibleBackend(base: "http://localhost:11434/v1", key: nil, displayName: "Ollama").models() {
                ollamaRunning = true; localModels = ms; localKind = .ollama
            } else { ollamaRunning = false; localModels = [] }
        }
        if !localModels.contains(where: { $0.id == localModel }) {
            localModel = localModels.first(where: \.loaded)?.id ?? recommendedInstalled?.id ?? localModels.first?.id ?? ""
        }
    }

    var recommended: LocalModelChoice { LocalModelChoice.recommended(ramGB: state.ramGB) }
    var recommendedInstalled: ModelInfo? { localModels.first { $0.id == recommended.key || $0.id.hasPrefix(recommended.key) } }

    func downloadRecommended() async {
        let key = recommended.key
        let lm = LMStudioBackend(base: "http://localhost:1234")
        download = (key, nil)
        do {
            guard let job = try await lm.startDownload(key) else {
                download = nil; await refreshLocal(); localModel = recommendedInstalled?.id ?? localModel; return
            }
            while true {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let s = try await lm.downloadStatus(job)
                download = (key, s.total > 0 ? Double(s.downloaded) / Double(s.total) : nil)
                if s.status == "completed" { break }
                if s.status == "failed" { localStatus = L.t("下载失败，可以在 LM Studio 里重试", "Download failed; try again in LM Studio"); break }
            }
        } catch {
            localStatus = L.t("连不上 LM Studio", "Can't reach LM Studio")
        }
        download = nil
        await refreshLocal()
        if let m = recommendedInstalled { localModel = m.id }
    }

    func saveLocal() {
        guard !localModel.isEmpty else { return }
        upsert(EngineConfig(id: "local", kind: localKind, name: localKind == .lmstudio ? "LM Studio" : "Ollama",
                            baseURL: localKind == .lmstudio ? "http://localhost:1234" : "http://localhost:11434", model: localModel))
    }

    func openLMStudio() {
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "ai.elementlabs.lmstudio") {
            NSWorkspace.shared.openApplication(at: u, configuration: .init())
        } else { NSWorkspace.shared.open(URL(string: "https://lmstudio.ai/download")!) }
    }
}

struct APICard: View {
    @Bindable var s: EngineSetup
    var onSaved: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.t("用 API", "Use an API"), systemImage: "cloud").font(.headline)
            Text(L.t("最快，不占内存；选中的文字会发给这家服务，按用量付费。", "Fastest, uses no memory. Selected text is sent to that service, paid by usage."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(L.t("服务", "Service"), selection: $s.service) {
                ForEach(APIService.all) { Text($0.name).tag($0) }
            }
            if s.service.id == "custom" {
                TextField(L.t("接口地址，例如 https://example.com/v1", "Address, e.g. https://example.com/v1"), text: $s.customURL)
            } else if let u = URL(string: s.service.keyURL) {
                Link(L.t("在 \(s.service.name) 网站上创建 API key ↗", "Create an API key on \(s.service.name) ↗"), destination: u).font(.caption)
            }
            SecureField("API key", text: $s.apiKey)
            HStack {
                Button(s.testing ? L.t("正在测试…", "Testing…") : L.t("测试", "Test")) { Task { await s.testAPI() } }.disabled(s.testing)
                if let st = s.apiStatus {
                    Text(st).font(.caption).foregroundStyle(s.apiOK ? .green : .red).fixedSize(horizontal: false, vertical: true)
                }
            }
            if s.apiOK && !s.apiModels.isEmpty {
                Picker(L.t("模型", "Model"), selection: $s.apiModel) {
                    ForEach(s.apiModels) { Text($0.id).tag($0.id) }
                }
                Text(L.t("保存后，选中的文字会发送给 \(s.service.name)。第一次在每个 App 里用之前还会再问一次。",
                         "Once saved, selected text is sent to \(s.service.name). You'll be asked once more in each app before the first use."))
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                Button(L.t("保存", "Save")) { s.saveAPI(); onSaved() }.keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct LocalCard: View {
    @Bindable var s: EngineSetup
    var onSaved: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.t("LM Studio 或 Ollama（已经在用的话）", "LM Studio or Ollama (if you already use one)"), systemImage: "server.rack").font(.headline)
            Text(L.t("发送到这台 Mac 上的 LM Studio，不经过网络，免费；要占几个 GB 内存，速度看机器。", "Sent to LM Studio on this Mac, not over the network; free. Uses a few GB of memory; speed depends on the Mac."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if s.lmRunning == nil {
                ProgressView().controlSize(.small)
            } else if s.lmRunning == true || s.ollamaRunning {
                Label(s.localKind == .lmstudio ? L.t("LM Studio 已连上", "LM Studio connected") : L.t("Ollama 已连上", "Ollama connected"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                if s.localModels.isEmpty {
                    Text(L.t("还没有下载模型。", "No models downloaded yet.")).font(.callout)
                } else {
                    Picker(L.t("模型", "Model"), selection: $s.localModel) {
                        ForEach(s.localModels) { m in
                            Text(m.name + (m.loaded ? L.t("（已在内存里）", " (loaded)") : "") + (m.id.hasPrefix(s.recommended.key) ? L.t("（推荐）", " (recommended)") : "")).tag(m.id)
                        }
                    }
                }
                if s.localKind == .lmstudio && s.recommendedInstalled == nil {
                    if let d = s.download {
                        ProgressView(value: d.fraction ?? 0) { Text(L.t("正在下载 \(s.recommended.name)…", "Downloading \(s.recommended.name)…")).font(.caption) }
                    } else {
                        Button(L.t("下载推荐的模型：\(s.recommended.name)（\(String(format: "%.1f", s.recommended.sizeGB)) GB，\(s.recommended.note)）",
                                   "Download the recommended model: \(s.recommended.name) (\(String(format: "%.1f", s.recommended.sizeGB)) GB, \(s.recommended.note))")) {
                            Task { await s.downloadRecommended() }
                        }
                    }
                }
                if !s.localModel.isEmpty {
                    Button(L.t("用这个模型", "Use this model")) { s.saveLocal(); onSaved() }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    check(s.lmInstalled, L.t("下载并打开 LM Studio（免费）", "Download and open LM Studio (free)"))
                    check(false, L.t("在 LM Studio 里打开本地服务（Developer → Status: Running）", "Turn on LM Studio's local server (Developer → Status: Running)"))
                    check(false, L.t("在这里一键下载推荐的模型", "Download the recommended model here, one click"))
                    check(false, L.t("在 LM Studio 设置里打开「登录时启动」", "Turn on “Launch at login” in LM Studio settings"))
                }.font(.callout)
                HStack {
                    Button(s.lmInstalled ? L.t("打开 LM Studio", "Open LM Studio") : L.t("下载 LM Studio ↗", "Get LM Studio ↗")) { s.openLMStudio() }
                    Button(L.t("重新检测", "Check again")) { Task { await s.refreshLocal() } }
                }
                Text(L.t("这一步每秒自动检测，连上后自动打勾。", "This checks every second and ticks itself once connected."))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let st = s.localStatus { Text(st).font(.caption).foregroundStyle(.red) }
        }
        .task {
            await s.refreshLocal()
            while !Task.isCancelled && s.lmRunning != true && !s.ollamaRunning {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await s.refreshLocal()
            }
        }
    }

    func check(_ done: Bool, _ t: String) -> some View {
        Label(t, systemImage: done ? "checkmark.square.fill" : "square").foregroundStyle(done ? .green : .primary)
    }
}

/// The built-in model card: the default way (design §7.7), no other app needed.
struct BuiltInCard: View {
    @Bindable var s: EngineSetup
    var onSaved: () -> Void = {}
    @Bindable private var models = BuiltInModels.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.t("内置模型（推荐）", "Built-in model (recommended)"), systemImage: "cpu").font(.headline)
            Text(L.t("在 GrammarBuddy 里运行，不用装别的 App。文字不会离开这台电脑。第一次要下载模型，之后不需要联网。",
                     "Runs inside GrammarBuddy; nothing else to install. Your text never leaves this Mac. The model downloads once; after that no internet is needed."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(BuiltInChoice.catalog) { c in
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: s.builtInModel == c.id ? "largecircle.fill.circle" : "circle")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name + " · " + String(format: "%.1f GB", c.sizeGB) + (c.id == BuiltInChoice.recommended(ramGB: s.state.ramGB).id ? L.t("（推荐给这台 \(s.state.ramGB) GB 的 Mac）", " (recommended for this \(s.state.ramGB) GB Mac)") : ""))
                        Text(c.note).font(.caption).foregroundStyle(.secondary)
                        status(c)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { s.builtInModel = c.id }
            }
            HStack {
                let st = models.state(s.builtInModel)
                if st == .ready {
                    Button(L.t("用这个模型", "Use this model")) { s.saveBuiltIn(); onSaved() }.keyboardShortcut(.defaultAction)
                } else if case .downloading = st {
                    Button(L.t("正在下载…", "Downloading…")) {}.disabled(true)
                } else {
                    Button(L.t("下载并使用", "Download and use")) {
                        Task { await models.download(s.builtInModel); if models.state(s.builtInModel) == .ready { s.saveBuiltIn(); onSaved() } }
                    }.keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    @ViewBuilder func status(_ c: BuiltInChoice) -> some View {
        switch models.state(c.id) {
        case .ready: Label(models.source(c.id), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
        case .downloading(let f):
            ProgressView(value: f ?? 0).frame(width: 220)
            Text(f.map { String(format: L.t("已下载 %.0f%%", "%.0f%% downloaded"), $0 * 100) } ?? L.t("正在开始下载…", "Starting…")).font(.caption)
        case .failed(let m): Text(m).font(.caption).foregroundStyle(.red)
        case .absent: Text(L.t("还没有下载", "Not downloaded yet")).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Apple Intelligence row (design §7.1): shown with its status; usable only when the system says so.
struct AppleIntelligenceRow: View {
    @Bindable var s: EngineSetup
    var body: some View {
        HStack {
            Label("Apple Intelligence", systemImage: "apple.logo").font(.headline)
            Spacer()
            if AppleIntelligence.status == .available {
                if s.state.engines.contains(where: { $0.kind == .apple }) { Text(L.t("已添加", "Added")).foregroundStyle(.secondary) }
                else { Button(L.t("添加", "Add")) { s.saveApple() } }
            } else {
                Text(AppleIntelligence.statusText).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }
    }
}
