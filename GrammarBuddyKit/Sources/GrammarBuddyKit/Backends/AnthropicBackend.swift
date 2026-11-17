// AnthropicBackend.swift
// Anthropic Messages API with streaming (design §7.3: "Anthropic's format differs, its own Backend").

import Foundation

public struct AnthropicBackend: Backend {
    public let base: String
    public let key: String
    static let version = "2023-06-01"

    public init(base: String, key: String) {
        self.base = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.key = key
    }

    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, timeout: TimeInterval) throws -> URLRequest {
        var r = try HTTP.request(base + path, method: method, body: body, timeout: timeout)
        r.setValue(nil, forHTTPHeaderField: "Authorization")
        r.setValue(key, forHTTPHeaderField: "x-api-key")
        r.setValue(Self.version, forHTTPHeaderField: "anthropic-version")
        return r
    }

    public func models() async throws -> [ModelInfo] {
        let r = try request("/models?limit=100", timeout: 8)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: r) } catch { throw HTTP.mapURLError(error, name: "Anthropic") }
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            throw HTTP.mapStatus(h.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = o["data"] as? [[String: Any]] else {
            throw EngineError.server(L.t("回应看不懂", "Unexpected reply"))
        }
        let ms = arr.compactMap { m -> ModelInfo? in
            guard let id = m["id"] as? String else { return nil }
            return ModelInfo(id: id, name: (m["display_name"] as? String) ?? id, loaded: false, sizeBytes: 0)
        }
        if ms.isEmpty { throw EngineError.noModels }
        return ms
    }

    public func run(_ req: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    let body: [String: Any] = ["model": model, "max_tokens": 4096, "stream": true, "temperature": req.temperature,
                                               "system": req.system, "messages": [["role": "user", "content": req.text]]]
                    let r = try request("/messages", method: "POST", body: body, timeout: 60)
                    let bytes: URLSession.AsyncBytes, resp: URLResponse
                    do { (bytes, resp) = try await URLSession.shared.bytes(for: r) } catch { throw HTTP.mapURLError(error, name: "Anthropic") }
                    if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
                        var msg = ""
                        for try await line in bytes.lines { msg += line; if msg.count > 2000 { break } }
                        throw HTTP.mapStatus(h.statusCode, body: msg)
                    }
                    var finish: FinishReason = .complete
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:"),
                              let o = try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: Any] else { continue }
                        switch o["type"] as? String {
                        case "content_block_delta":
                            let d = o["delta"] as? [String: Any]
                            if (d?["type"] as? String) == "thinking_delta" { cont.yield(.thinking) }
                            if let t = d?["text"] as? String, !t.isEmpty { cont.yield(.text(t)) }
                        case "message_delta":
                            if ((o["delta"] as? [String: Any])?["stop_reason"] as? String) == "max_tokens" { finish = .truncated }
                        case "error":
                            throw EngineError.server(((o["error"] as? [String: Any])?["message"] as? String) ?? "Anthropic error")
                        default: break
                        }
                    }
                    cont.yield(.finished(finish))
                    cont.finish()
                } catch { cont.finish(throwing: error) }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}
