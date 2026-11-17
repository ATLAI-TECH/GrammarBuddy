// LMStudioBackend.swift
// LM Studio's own API (design §7.2): /api/v1/models, /api/v1/models/download, /api/v1/chat with reasoning:"off".
// Same approach as ScienceSkim's apple/Skim/Support/LMStudio.swift.

import Foundation

public struct LMStudioBackend: Backend {
    public let base: String
    public init(base: String) { self.base = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) }

    public func models() async throws -> [ModelInfo] {
        let r = try HTTP.request(base + "/api/v1/models", timeout: 2)
        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: r) } catch { throw HTTP.mapURLError(error, name: "LM Studio") }
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let arr = o["models"] as? [[String: Any]] else {
            throw EngineError.server(L.t("LM Studio 的回应看不懂", "Unexpected reply from LM Studio"))
        }
        return arr.compactMap { m in
            guard (m["type"] as? String) == "llm", let key = m["key"] as? String else { return nil }   // drop embedding models
            return ModelInfo(id: key, name: (m["display_name"] as? String) ?? key,
                             loaded: !((m["loaded_instances"] as? [Any]) ?? []).isEmpty,
                             sizeBytes: (m["size_bytes"] as? NSNumber)?.int64Value ?? 0)
        }
    }

    public func run(_ req: EngineRequest, model: String) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    try await stream(req, model: model, reasoningOff: req.disableThinking, cont: cont)
                } catch EngineError.server(let m) where req.disableThinking && m.lowercased().contains("reasoning") {
                    // the model doesn't support turning reasoning off: send again without it (§7.2)
                    do { try await stream(req, model: model, reasoningOff: false, cont: cont) } catch { cont.finish(throwing: error) }
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    private func stream(_ req: EngineRequest, model: String, reasoningOff: Bool,
                        cont: AsyncThrowingStream<EngineEvent, Error>.Continuation) async throws {
        var body: [String: Any] = ["model": model, "system_prompt": req.system, "input": req.text, "stream": true,
                                   "temperature": req.temperature, "context_length": 8192, "store": false]
        if reasoningOff { body["reasoning"] = "off" }
        let r = try HTTP.request(base + "/api/v1/chat", method: "POST", body: body, timeout: 60)
        let bytes: URLSession.AsyncBytes, resp: URLResponse
        do { (bytes, resp) = try await URLSession.shared.bytes(for: r) } catch { throw HTTP.mapURLError(error, name: "LM Studio") }
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var msg = ""
            for try await line in bytes.lines { msg += line; if msg.count > 2000 { break } }
            throw HTTP.mapStatus(http.statusCode, body: msg)
        }
        var gotText = false, sentThinking = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:"),
                  let o = try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: Any] else { continue }
            let type = o["type"] as? String ?? ""
            switch type {
            case "model_load.start", "model_load.progress":
                cont.yield(.loadingModel)
            case _ where type.hasPrefix("reasoning"):
                if !sentThinking { cont.yield(.thinking); sentThinking = true }
            case "message.delta":
                if let s = o["content"] as? String, !s.isEmpty { gotText = true; cont.yield(.text(s)) }
            case "error":
                throw EngineError.server(((o["error"] as? [String: Any])?["message"] as? String) ?? "LM Studio error")
            case "chat.end":
                let res = o["result"] as? [String: Any]
                if !gotText, let out = res?["output"] as? [[String: Any]] {
                    let s = out.filter { ($0["type"] as? String) == "message" }.compactMap { $0["content"] as? String }.joined()
                    if !s.isEmpty { cont.yield(.text(s)) }
                }
                let stop = ((res?["stats"] as? [String: Any])?["stop_reason"] as? String) ?? ""
                cont.yield(.finished(stop.lowercased().contains("max") ? .truncated : .complete))
                cont.finish()
                return
            default: break
            }
        }
        cont.yield(.finished(.complete))
        cont.finish()
    }

    // MARK: one-click model download (§2.10 step 4)

    public struct DownloadStatus: Sendable { public var status: String; public var downloaded: Int64; public var total: Int64 }

    public func startDownload(_ key: String) async throws -> String? {
        let r = try HTTP.request(base + "/api/v1/models/download", method: "POST", body: ["model": key], timeout: 30)
        let (data, _) = try await URLSession.shared.data(for: r)
        let o = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if (o?["status"] as? String) == "already_downloaded" { return nil }
        return o?["job_id"] as? String
    }

    public func downloadStatus(_ job: String) async throws -> DownloadStatus {
        let r = try HTTP.request(base + "/api/v1/models/download/status/\(job)", timeout: 5)
        let (data, _) = try await URLSession.shared.data(for: r)
        let o = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return DownloadStatus(status: o["status"] as? String ?? "downloading",
                              downloaded: (o["downloaded_bytes"] as? NSNumber)?.int64Value ?? 0,
                              total: (o["total_size_bytes"] as? NSNumber)?.int64Value ?? 0)
    }
}

/// Recommended local models by memory (§7.5), from docs/MODELS.md (round 6). qwen3-8b is left out on purpose:
/// with thinking off it returns most faulty texts unchanged.
public struct LocalModelChoice: Sendable, Identifiable, Hashable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let sizeGB: Double
    public let minRAM: Int
    public let note: String

    public static var catalog: [LocalModelChoice] {[
        LocalModelChoice(key: "qwen/qwen3-4b-2507", name: "Qwen3 4B", sizeGB: 2.3, minRAM: 8,
                         note: L.t("小而快，8–16 GB 内存；改错要看差异", "Small and fast, 8–16 GB; check each fix")),
        LocalModelChoice(key: "qwen/qwen3-14b", name: "Qwen3 14B", sizeGB: 8.4, minRAM: 24,
                         note: L.t("最准，24 GB 以上（第 6 轮评审推荐）", "Most accurate, 24 GB+ (recommended by review round 6)")),
    ]}

    public static func recommended(ramGB: Int) -> LocalModelChoice {
        catalog.last { $0.minRAM <= max(8, ramGB) } ?? catalog[0]
    }
}
