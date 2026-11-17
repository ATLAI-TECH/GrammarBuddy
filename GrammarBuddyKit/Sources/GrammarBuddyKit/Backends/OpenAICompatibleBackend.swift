// OpenAICompatibleBackend.swift
// /v1/chat/completions with streaming. Used for APIs (OpenAI, OpenRouter, DeepSeek, …) and Ollama (design §7.2–7.3).

import Foundation

public struct OpenAICompatibleBackend: Backend {
    public let base: String
    public let key: String?
    public let displayName: String

    public init(base: String, key: String?, displayName: String) {
        self.base = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.key = key; self.displayName = displayName
    }

    public func models() async throws -> [ModelInfo] {
        if Destination.classify(base) == .internet && !base.lowercased().hasPrefix("https://") { throw EngineError.insecureURL }
        let r = try HTTP.request(base + "/models", key: key, timeout: 8)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: r) } catch { throw HTTP.mapURLError(error, name: displayName) }
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            throw HTTP.mapStatus(h.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = o["data"] as? [[String: Any]] else {
            throw EngineError.server(L.t("回应看不懂", "Unexpected reply"))
        }
        let ms = arr.compactMap { m -> ModelInfo? in
            guard let id = m["id"] as? String, !id.lowercased().contains("embed") else { return nil }
            return ModelInfo(id: id, name: (m["name"] as? String) ?? id, loaded: false, sizeBytes: 0)
        }
        if ms.isEmpty { throw EngineError.noModels }
        return ms
    }

    public func run(_ req: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    if Destination.classify(base) == .internet && !base.lowercased().hasPrefix("https://") { throw EngineError.insecureURL }
                    let body: [String: Any] = ["model": model, "stream": true, "temperature": req.temperature,
                                               "messages": [["role": "system", "content": req.system], ["role": "user", "content": req.text]]]
                    let r = try HTTP.request(base + "/chat/completions", method: "POST", body: body, key: key, timeout: 60)
                    let bytes: URLSession.AsyncBytes, resp: URLResponse
                    do { (bytes, resp) = try await URLSession.shared.bytes(for: r) } catch { throw HTTP.mapURLError(error, name: displayName) }
                    if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
                        var msg = ""
                        for try await line in bytes.lines { msg += line; if msg.count > 2000 { break } }
                        throw HTTP.mapStatus(h.statusCode, body: msg)
                    }
                    var thinking = false, inThinkTag = false
                    var finish: FinishReason = .complete
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let o = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                              let ch = (o["choices"] as? [[String: Any]])?.first else { continue }
                        let d = ch["delta"] as? [String: Any] ?? [:]
                        if (d["reasoning_content"] as? String ?? d["reasoning"] as? String)?.isEmpty == false, !thinking {
                            thinking = true; cont.yield(.thinking)
                        }
                        if var s = d["content"] as? String, !s.isEmpty {
                            // <think> in the text stream: unify into .thinking (§4.3)
                            if s.contains("<think>") { inThinkTag = true; if !thinking { thinking = true; cont.yield(.thinking) } }
                            if inThinkTag {
                                if let end = s.range(of: "</think>") { s = String(s[end.upperBound...]); inThinkTag = false } else { continue }
                            }
                            if !s.isEmpty { cont.yield(.text(s)) }
                        }
                        if (ch["finish_reason"] as? String) == "length" { finish = .truncated }
                    }
                    cont.yield(.finished(finish))
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}
