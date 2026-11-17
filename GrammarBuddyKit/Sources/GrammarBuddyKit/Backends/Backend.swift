// Backend.swift
// AI engines (design §4.3, §7). Two first-class kinds: self-hosted (LM Studio / Ollama) and API.

import Foundation

/// How GrammarBuddy reaches a model. `builtin` and `apple` run inside this Mac and are created by the app layer
/// (MLX and FoundationModels live there); the others are HTTP backends in this package.
public enum EngineKind: String, Codable, Sendable { case builtin, apple, lmstudio, ollama, api, anthropic

    public var isLocal: Bool { self == .builtin || self == .apple || self == .lmstudio || self == .ollama }
}

public struct EngineConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: EngineKind
    public var name: String              // "LM Studio", "OpenRouter", …
    public var baseURL: String           // http://localhost:1234 or https://api.openai.com/v1
    public var model: String
    public var keychainAccount: String?  // API key lives in the Keychain, never here (§7.3)

    public init(id: String = UUID().uuidString, kind: EngineKind, name: String, baseURL: String, model: String, keychainAccount: String? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.baseURL = baseURL; self.model = model; self.keychainAccount = keychainAccount
    }
}

public struct EngineRequest: Sendable {
    public var system: String
    public var text: String
    public var temperature: Double = 0      // T5-09: same text, same result
    public var disableThinking = true
    public init(system: String, text: String) { self.system = system; self.text = text }
}

public enum EngineEvent: Sendable, Equatable {
    case loadingModel, thinking, text(String), finished(FinishReason)
}

public enum EngineError: Error, Equatable, Sendable {
    case notRunning(String)        // LM Studio / Ollama not open
    case noModel
    case badKey, quotaOrRateLimit, unreachable(String), noModels, insecureURL, timeout
    case server(String)

    public var message: String {
        switch self {
        case .notRunning(let n): return L.t("\(n) 没有打开", "\(n) isn't running")
        case .noModel: return L.t("还没有选模型", "No model chosen yet")
        case .badKey: return L.t("API key 不对", "The API key was rejected")
        case .quotaOrRateLimit: return L.t("余额不足或被限流", "Out of credit or rate-limited")
        case .unreachable(let d): return L.t("连不上这个地址", "Can't reach this address") + (d.isEmpty ? "" : " (\(d))")
        case .noModels: return L.t("这个服务没有可用的模型", "This service has no models available")
        case .insecureURL: return L.t("公网地址必须是 https", "Internet addresses must use https")
        case .timeout: return L.t("等太久没有回应", "No response in time")
        case .server(let m): return m
        }
    }
}

public struct ModelInfo: Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var loaded: Bool
    public var sizeBytes: Int64
    public init(id: String, name: String, loaded: Bool, sizeBytes: Int64) { self.id = id; self.name = name; self.loaded = loaded; self.sizeBytes = sizeBytes }
}

public protocol Backend: Sendable {
    func models() async throws -> [ModelInfo]
    func run(_ request: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error>
}

public enum BackendFactory {
    public static func make(_ c: EngineConfig, key: String?) -> Backend {
        switch c.kind {
        case .lmstudio: return LMStudioBackend(base: c.baseURL)
        case .ollama: return OpenAICompatibleBackend(base: c.baseURL.hasSuffix("/v1") ? c.baseURL : c.baseURL + "/v1", key: nil, displayName: "Ollama")
        case .api: return OpenAICompatibleBackend(base: c.baseURL, key: key, displayName: c.name)
        case .anthropic: return AnthropicBackend(base: c.baseURL, key: key ?? "")
        case .builtin, .apple: return UnavailableBackend(name: c.name)   // the app supplies these
        }
    }
}

/// Built-in API services (§7.3). "Custom" accepts any OpenAI-compatible address.
public struct APIService: Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var baseURL: String
    public var keyURL: String
    public var kind: EngineKind = .api          // .anthropic uses its own format
    public static var all: [APIService] {[
        APIService(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1", keyURL: "https://platform.openai.com/api-keys"),
        APIService(id: "anthropic", name: "Anthropic Claude", baseURL: "https://api.anthropic.com/v1", keyURL: "https://console.anthropic.com/settings/keys", kind: .anthropic),
        APIService(id: "gemini", name: "Google Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai", keyURL: "https://aistudio.google.com/apikey"),
        APIService(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1", keyURL: "https://openrouter.ai/keys"),
        APIService(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com/v1", keyURL: "https://platform.deepseek.com/api_keys"),
        APIService(id: "siliconflow", name: "SiliconFlow", baseURL: "https://api.siliconflow.cn/v1", keyURL: "https://cloud.siliconflow.cn/account/ak"),
        APIService(id: "custom", name: L.t("自定义（OpenAI 兼容）", "Custom (OpenAI-compatible)"), baseURL: "", keyURL: ""),
    ]}
}

/// Placeholder for engines the app layer must create (built-in MLX model, Apple Intelligence).
public struct UnavailableBackend: Backend {
    public let name: String
    public init(name: String) { self.name = name }
    public func models() async throws -> [ModelInfo] { [] }
    public func run(_ request: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { $0.finish(throwing: EngineError.server(name + " is not available here")) }
    }
}

// MARK: shared SSE helpers

enum HTTP {
    static func request(_ url: String, method: String = "GET", body: [String: Any]? = nil, key: String? = nil, timeout: TimeInterval) throws -> URLRequest {
        guard let u = URL(string: url) else { throw EngineError.unreachable(url) }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = method
        if let key, !key.isEmpty { r.setValue("Bearer " + key, forHTTPHeaderField: "Authorization") }
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    static func mapStatus(_ code: Int, body: String) -> EngineError {
        switch code {
        case 401, 403: return .badKey
        case 402, 429: return .quotaOrRateLimit
        case 404: return .server(L.t("找不到这个模型或地址。到设置 → AI 里换一个模型，或者在那里下载推荐的模型。", "That model or address wasn't found. Choose another model in Settings → AI, or download the recommended one there."))
        default:
            let msg = (try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String ?? $0["error"] as? String } ?? body
            // G5-17: a plain sentence first, the service's own words after it
            return .server(L.t("服务返回了错误（HTTP \(code)）。详情：", "The service returned an error (HTTP \(code)). Details: ") + String(msg.prefix(160)))
        }
    }

    static func mapURLError(_ e: Error, name: String) -> Error {
        guard let u = e as? URLError else { return e }
        switch u.code {
        case .cannotConnectToHost, .networkConnectionLost: return EngineError.notRunning(name)
        case .timedOut: return EngineError.timeout
        case .appTransportSecurityRequiresSecureConnection: return EngineError.server(L.t("被系统的传输安全策略拦截", "Blocked by the system's App Transport Security"))
        default: return EngineError.unreachable(u.localizedDescription)
        }
    }
}
