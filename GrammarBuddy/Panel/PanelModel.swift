// PanelModel.swift
// One panel session: capture → operation → stream → clean → diff and checks → recommendation (design §2, §6).

import AppKit
import GrammarBuddyKit
import Observation

enum Phase: Equatable {
    case input                    // no selection: type or paste (§2.6)
    case askSource                // translation: language detection not sure (§2.5)
    case askConsent               // API: first use in this app (§7.4 safeguard 2)
    case tooLong(Int)             // AI limit (§2.7); associated: paragraphs that fit
    case needsDownload            // system translation language pack (§7.6)
    case working(Status)
    case done
    case failed(Failure)

    enum Status: Equatable { case reading, loadingModel, thinking, streaming, translating(Int) }
}

struct Failure: Equatable {
    var message: String
    var action: FailureAction?
}
enum FailureAction: Equatable { case setUpModel, openSettings, openLMStudio, retry, grantAccessibility, chooseEngine, openAutomationSettings }

struct ResultNote: Equatable {
    var text: String
    var undo: Bool = false
}

@MainActor
@Observable
final class PanelModel {
    let state = AppState.shared
    var capture: Capture?
    var handle: WriteHandle?
    var profile = AppProfile()
    var appName = ""
    var operation: TextOperation = .fix
    var tone: Tone = .formal
    var phase: Phase = .working(.reading)
    var manualText = ""
    var inputReason: String?
    var output = ""                // cleaned, shown
    var raw = ""
    var changes: [Change] = []
    var checks = CheckResult()
    var finish: FinishReason = .complete
    var focusedChange = -1
    var showDiff = true
    var showOriginal = false
    var leftPanel = false
    var confirmArmed = false
    var note: ResultNote? {
        didSet { if let n = note, n != oldValue, !n.text.isEmpty { Announcer.say(n.text, high: true) } }   // K5-05: every result bar is spoken
    }
    var thinkingSeconds = 0
    var sourceLang = "en"
    var targetLang = "zh-Hans"
    var translatedParas: [String?] = []
    var paragraphLimitNote: String?
    var quoteNote: String?
    var engineOverride: String?    // engine id chosen in the badge menu for this session
    var useSystemTranslation = true
    var sourceConfirmed = false
    var showTonePicker = false
    var showLanguageMenu = false
    var didWrite = false
    var lastWordWrite: (changes: [Change], newLength: Int)?
    var qaSimulated = false        // QA harness capture: writes are logged, not performed
    var qaLog: [String] = []
    var panelFill = false                 // the user dragged the panel to a size: the text area fills it
    var panelMaxContent: CGFloat = 300    // tallest the text area grows by itself (translation gets more)
    var onClose: (() -> Void)?
    var onYieldKeyboard: (() async -> Void)?
    var onReclaimKeyboard: (() -> Void)?

    private var task: Task<Void, Never>?
    private var timer: Timer?

    // MARK: engine choice (§7.4)

    /// The app the text came from; kept for typed / pasted text too, so consent and local-only still apply (G5-02).
    var sourceBundle: String?
    var askLanding = false     // "did last time's replace land in the right place?" (§2.4, T5-03)

    func answerLanding(_ yes: Bool) {
        guard let b = capture?.app?.bundleID else { return }
        state.askAssumeEditable.removeAll { $0 == b }
        if yes { if !state.assumeEditableApps.contains(b) { state.assumeEditableApps.append(b) }; profile.assumeEditable = true }
        askLanding = false
    }

    var engine: EngineConfig? {
        // §7.4 safeguard 3 wins over everything, including a pick in the badge menu (G5-01)
        if localOnlyHere { return state.localEngine }
        if let id = engineOverride, let e = state.engines.first(where: { $0.id == id }) { return e }
        return state.activeEngine
    }

    var localOnlyHere: Bool { (capture?.app?.bundleID ?? sourceBundle).map { state.localOnlyApps.contains($0) } ?? false }

    /// Engines the badge menu may offer here.
    var selectableEngines: [EngineConfig] { localOnlyHere ? state.engines.filter { $0.kind.isLocal } : state.engines }

    var usesSystemTranslation: Bool { operation == .translate && useSystemTranslation }

    /// Badge text (§7.4): only what the app actually knows.
    var badge: (text: String, leaves: Bool) {
        if usesSystemTranslation { return (L.t("系统翻译 · 在这台 Mac 上", "System translation · on this Mac"), false) }
        guard let e = engine else { return (L.t("没有 AI 引擎", "No AI engine"), false) }
        let model = e.model.split(separator: "/").last.map(String.init) ?? e.model
        switch Destination.classify(e.baseURL) {
        case .thisMac:
            if e.kind == .builtin {
                let n = BuiltInModels.shared.choice(e.model)?.name ?? model
                return (L.t("内置 · \(n) · 文字不出这台 Mac", "Built-in · \(n) · stays on this Mac"), false)
            }
            if e.kind == .apple { return (L.t("Apple Intelligence · 文字不出这台 Mac", "Apple Intelligence · stays on this Mac"), false) }
            return (L.t("这台 Mac · \(e.name) · \(model)", "This Mac · \(e.name) · \(model)"), false)
        case .localNetwork: return (L.t("局域网 · \(URL(string: e.baseURL)?.host ?? "")", "Local network · \(URL(string: e.baseURL)?.host ?? "")"), true)
        case .myDevice: return (L.t("我的设备 · \(URL(string: e.baseURL)?.host ?? "")", "My device · \(URL(string: e.baseURL)?.host ?? "")"), true)
        case .internet: return ("API · \(e.name) · \(model)", true)
        }
    }

    // MARK: start

    func start(outcome: ReadOutcome?, failure: ReadFailure?, operation op: TextOperation, appName: String) {
        self.appName = appName
        operation = op
        sourceBundle = outcome?.capture.app?.bundleID ?? sourceBundle
        if let t = state.lastTone { tone = t } else if op == .tone { showTonePicker = true }
        if let o = outcome {
            capture = o.capture
            handle = o.handle
            profile = AppProfiles.profile(for: o.capture.app?.bundleID ?? "")
            if let b = o.capture.app?.bundleID {
                profile.assumeEditable = state.assumeEditableApps.contains(b)
                askLanding = state.askAssumeEditable.contains(b) && !profile.emptyCopyCopiesLine
            }
            showOriginal = o.capture.via == .clipboard
            run()
        } else {
            capture = nil
            inputReason = failure?.message ?? ReadFailure.noSelection.message
            phase = .input
            Announcer.say(inputReason ?? "", high: true)     // K5-06
        }
    }

    func submitManual() {
        let t = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var c = Capture(raw: manualText, via: .manual, editability: .readOnly)
        if let b = sourceBundle { c.app = TargetApp(bundleID: b, name: appName, pid: 0) }   // consent and local-only per app (G5-02)
        capture = c
        run()
    }

    func useClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) { manualText = s }
    }

    // MARK: run

    func switchOperation(_ op: TextOperation) {
        if op == .tone && operation == .tone { showTonePicker.toggle(); return }
        operation = op
        if op == .tone && state.lastTone == nil { showTonePicker = true; cancel(); phase = .done; output = ""; changes = []; return }
        if capture != nil { run() }
    }

    func chooseTone(_ t: Tone) {
        tone = t
        state.lastTone = t
        showTonePicker = false
        run()
    }

    func cancel() {
        task?.cancel(); task = nil
        timer?.invalidate(); timer = nil
    }

    func run(skipLimit: Bool = false, consentGiven: Bool = false) {
        cancel()
        guard var cap = capture else { phase = .input; return }
        output = ""; raw = ""; changes = []; checks = CheckResult(); confirmArmed = false; note = nil; finish = .complete
        thinkingSeconds = 0; translatedParas = []; didWrite = false; lastWordWrite = nil

        if operation == .translate {
            if !sourceConfirmed {
                let det = LanguageDirection.detect(cap.text, preferred: state.myLanguages)
                sourceLang = det.language.map(LanguageDirectionHelpers.base) ?? (state.myLanguages.first ?? "en")
                targetLang = LanguageDirection.target(source: sourceLang, mine: state.myLanguages, lastTargets: state.lastTargets)
                if !det.confident { phase = .askSource; return }
                sourceConfirmed = true
            }
            if state.joinHardWraps { cap.text = LanguageDirection.joinHardWraps(cap.text) }
            if translationEngineOverride == nil {
                let saved = Store.defaults.object(forKey: "gb_translate_mode") as? Int ?? (state.translateWithAI ? 1 : 0)
                useSystemTranslation = saved == 0 || engine == nil
                polishTranslation = saved == 2 && engine != nil
            }
            else { useSystemTranslation = translationEngineOverride! }
            if useSystemTranslation { translateSystem(cap.text); return }
        }

        // AI operations
        guard let e = engine else {
            if localOnlyHere {
                phase = .failed(Failure(message: L.t("这个 App 设成了只用本机的模型，但还没有配置本机模型，所以不处理。",
                                                      "This app is set to use only a local model, and none is set up, so nothing was sent."), action: .openSettings))
            } else {
                phase = .failed(Failure(message: L.t("\(OpNames.name(operation))需要一个 AI 模型，这台 Mac 上还没有设置。翻译不需要，照常可用。",
                                                      "\(OpNames.name(operation)) needs an AI model and none is set up on this Mac yet. Translation works without one."), action: .setUpModel))
            }
            return
        }
        // §7.4 safeguard 2: ask once per app before the first API call
        if Destination.classify(e.baseURL) != .thisMac, !consentGiven,
           (cap.app.map { state.apiAllowedApps[e.id + "|" + $0.bundleID] != true } ?? true) {
            phase = .askConsent
            showOriginal = true
            return
        }
        if !skipLimit && (cap.text as NSString).length > 3000 {
            phase = .tooLong(fittingParagraphs(cap.text))
            return
        }
        let text = cap.text
        let srcName = operation == .translate ? nil
            : LanguageDirection.detect(text).language.map { LanguageDirection.englishName(LanguageDirectionHelpers.base($0)) }
        let system = Prompts.system(for: operation, tone: tone, target: LanguageDirection.englishName(targetLang),
                                    protectedWords: state.protectedWords, sourceLanguage: srcName,
                                    polishTranslation: operation == .translate && polishTranslation)
        var backend = Engines.backend(for: e)
        var model = e.model
        #if DEBUG
        // QA only: an "API" engine whose requests actually go to the local LM Studio (no real key in the test lab)
        if e.kind == .api && Store.defaults.bool(forKey: "gb_qa_api_via_local") {
            backend = LMStudioBackend(base: "http://localhost:1234")
            model = state.localEngine?.model ?? "qwen/qwen3-14b"
        }
        #endif
        phase = .working(.streaming)
        let op = operation
        let started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.thinkingSeconds = Int(Date().timeIntervalSince(started))
            }
        }
        task = Task { [weak self] in
            var req = EngineRequest(system: system, text: text)
            req.disableThinking = true
            do {
                var gotFirst = false
                for try await ev in backend.run(req, model: model) {
                    guard let self, !Task.isCancelled else { return }
                    switch ev {
                    case .loadingModel: if !gotFirst { self.phase = .working(.loadingModel) }
                    case .thinking: if !gotFirst { self.phase = .working(.thinking) }
                    case .text(let s):
                        gotFirst = true
                        self.raw += s
                        self.phase = .working(.streaming)
                        self.output = Cleaner.clean(self.raw, original: text, operation: op, targetLanguage: self.targetLang)
                        // §6.5: stop when the result is 3× longer than the original
                        if op != .translate, Tokenizer.tokens(self.output).filter(\.isWord).count > 3 * max(cap.wordCount, 1) + 8 {
                            self.finish = .truncated
                            self.complete(text: text)
                            return
                        }
                    case .finished(let f):
                        self.finish = f
                    }
                }
                guard !Task.isCancelled else { return }
                self?.complete(text: text)
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.timer?.invalidate()
                let f = self.failure(for: error, engine: e)
                self.phase = .failed(f)
                Announcer.say(f.message, high: true)
                if case .notRunning = error as? EngineError, e.kind == .lmstudio { self.pollLMStudio(e) }
            }
        }
    }

    private func failure(for error: Error, engine e: EngineConfig) -> Failure {
        if let ee = error as? EngineError {
            switch ee {
            case .notRunning:
                if e.kind == .lmstudio { return Failure(message: L.t("LM Studio 没有打开。打开后会自动重试。也可以在设置 → AI 里改用内置模型。", "LM Studio isn't running. It will retry automatically once it's open."), action: .openLMStudio) }
                return Failure(message: ee.message, action: .retry)
            case .server(let m) where m.contains("Settings → AI") || m.contains("设置 → AI"):
                return Failure(message: ee.message, action: .openSettings)
            case .badKey, .quotaOrRateLimit, .insecureURL, .noModels:
                return Failure(message: e.name + L.t("：", ": ") + ee.message + L.t("请检查 key 是否完整复制、账户是否还有余额。", " Check that you copied the whole key and that the account has credit."), action: .openSettings)
            default:
                return Failure(message: ee.message, action: .retry)
            }
        }
        return Failure(message: error.localizedDescription, action: .retry)
    }

    private var pollTask: Task<Void, Never>?
    func pollLMStudio(_ e: EngineConfig) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            for i in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if (try? await LMStudioBackend(base: e.baseURL).models()) != nil {
                    await MainActor.run { self?.run() }
                    return
                }
                if i == 59 {
                    await MainActor.run {
                        self?.phase = .failed(Failure(message: L.t("还没有连上，LM Studio 里的本地服务可能没有开启（Developer → Status: Running）。",
                                                                    "Still can't connect. LM Studio's local server may be off (Developer → Status: Running)."), action: .retry))
                    }
                }
            }
        }
    }

    func openLMStudio() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = false            // in the background, the panel stays in front (§2.9)
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "ai.elementlabs.lmstudio") {
            NSWorkspace.shared.openApplication(at: u, configuration: cfg)
        } else {
            NSWorkspace.shared.open(URL(string: "https://lmstudio.ai/download")!)
        }
        if let e = engine { pollLMStudio(e) }
    }

    private func complete(text: String) {
        timer?.invalidate()
        task = nil
        output = Cleaner.clean(raw, original: text, operation: operation, targetLanguage: targetLang)
        checks = Checks.run(original: text, result: output, operation: operation, protectedWords: state.protectedWords,
                            sourceLanguage: sourceLang, targetLanguage: targetLang)
        // an empty answer is a failure, never a "delete everything" change
        if operation != .translate && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { computeChanges(original: text) }
        else {
            let src = text.components(separatedBy: "\n"), out = output.components(separatedBy: "\n")
            translatedParas = src.count == out.count ? out : []
        }
        phase = .done
        if (capture?.text.count ?? 0) > 200 { showOriginal = false }    // T5-06: make room for the result
        Announcer.say(doneAnnouncement, high: true)
        if let cap = capture {
            state.remember(HistoryItem(operation: operation, original: cap.text, result: finalText, appName: appName))
        }
    }

    func computeChanges(original: String) {
        var cs = WordDiff.changes(from: original, to: output)
        let prot = Set(checks.protectedChanged)
        for i in cs.indices where prot.contains(where: { cs[i].removed.contains($0) }) {
            cs[i].flags.insert(.protected)
            cs[i].accepted = false       // G5-06: a changed date or number is never taken by default
        }
        // direct quotations: what someone said is not corrected by default (round 7, M7-01)
        let quotes = Quotes.ranges(in: original)
        var inQuotes = 0
        for i in cs.indices where Quotes.contains(cs[i].range, in: quotes) {
            cs[i].flags.insert(.inQuote)
            cs[i].accepted = false
            inQuotes += 1
        }
        quoteNote = inQuotes > 0 ? L.t("\(inQuotes) 处改动在引语里，默认不采用（点一下可以采用）", "\(inQuotes) change(s) are inside a quotation and are not applied by default (click one to apply it)") : nil
        // Word: changes that can't be written as tracked changes (§2.8) start unaccepted and flagged
        if capture?.via == .word, let info = handle?.wordInfo {
            let skip = WordBridge.skipped(cs, info: info, bySentence: operation == .polish || operation == .tone)
            for i in skip.keys { cs[i].flags.insert(.skippedInWord); cs[i].accepted = false }
            if !skip.isEmpty {
                note = ResultNote(text: L.t("其中 \(skip.count) 处不会写入：", "\(skip.count) of these won't be written: ")
                                  + Set(skip.values).sorted().joined(separator: L.t("；", "; ")))
            }
        }
        changes = cs
        focusedChange = -1
    }

    // MARK: system translation (§2.7, §7.6)

    func translateSystem(_ text: String) {
        let from = sourceLang, to = targetLang
        phase = .working(.translating(text.components(separatedBy: "\n").filter { !$0.isEmpty }.count))
        task = Task { [weak self] in
            let st = await SystemTranslator.status(from: from, to: to)
            guard let self, !Task.isCancelled else { return }
            switch st {
            case .unsupported:
                self.phase = .failed(Failure(message: L.t("系统翻译不支持 \(LanguageDirection.displayName(from)) → \(LanguageDirection.displayName(to))。可以改用 AI 翻译（右上角）。",
                                                          "System translation doesn't support \(LanguageDirection.displayName(from)) → \(LanguageDirection.displayName(to)). Switch to AI translation (top right)."), action: .chooseEngine))
                return
            case .needsDownload:
                self.phase = .needsDownload
                Announcer.say(L.t("这对语言需要先下载系统语言包", "This language pair needs a one-time system download"), high: true)
                return
            case .ready: break
            }
            let paras = text.components(separatedBy: "\n")
            do {
                let res = try await SystemTranslator.translate(paras, from: from, to: to)
                guard !Task.isCancelled else { return }
                self.translatedParas = res
                self.output = zip(paras, res).map { $1 ?? $0 }.joined(separator: "\n")
                self.checks = Checks.run(original: text, result: self.output, operation: .translate, protectedWords: [], sourceLanguage: from, targetLanguage: to)
                self.finish = .complete
                self.phase = .done
                Announcer.say(self.doneAnnouncement, high: true)
                if let cap = self.capture { self.state.remember(HistoryItem(operation: .translate, original: cap.text, result: self.output, appName: self.appName)) }
            } catch {
                self.phase = .failed(Failure(message: error.localizedDescription, action: .retry))
            }
        }
    }

    func downloadLanguages() {
        SystemTranslator.download(from: sourceLang, to: targetLang) { [weak self] ok in
            guard let self else { return }
            if ok { self.run() } else { self.phase = .failed(Failure(message: L.t("没有下载语言包。翻译需要先联网下载一次。", "The language pack wasn't downloaded. Translation needs a one-time download."), action: .retry)) }
        }
    }

    func setTarget(_ code: String, remember: Bool) {
        targetLang = code
        if remember { var t = state.lastTargets; t[sourceLang] = code; state.lastTargets = t }
        showLanguageMenu = false
        run()
    }

    /// The ⇄ button: translate the other way round (English → Chinese becomes Chinese → English). Used when the
    /// guess at the source language was wrong, or the text mixes both and the other direction was meant.
    func swapLanguages() {
        guard sourceLang != targetLang else { return }
        (sourceLang, targetLang) = (targetLang, sourceLang)
        showLanguageMenu = false
        sourceConfirmed = true
        run()
    }

    func setSource(_ code: String) {
        sourceLang = code
        targetLang = LanguageDirection.target(source: code, mine: state.myLanguages, lastTargets: state.lastTargets)
        if phase != .askSource { sourceConfirmed = true; run() }
    }

    /// First use, no model yet: one click in the panel sets up the built-in model (downloading it if this Mac doesn't
    /// have it) and then does what was asked. No trip to Settings.
    func useBuiltInModel(_ id: String) {
        Task {
            let models = BuiltInModels.shared
            if models.state(id) != .ready { await models.download(id) }
            guard models.state(id) == .ready else { return }        // the failure is shown by the quick-start view
            let s = EngineSetup()
            s.builtInModel = id
            s.saveBuiltIn()
            run()
        }
    }

    func confirmSourceAndRun() {
        sourceConfirmed = true
        targetLang = LanguageDirection.target(source: sourceLang, mine: state.myLanguages, lastTargets: state.lastTargets)
        run()
    }

    /// For this panel only; the default stays in Settings → Languages (E5-03).
    var translationEngineOverride: Bool?
    /// "Translate and polish": AI translation whose result is also polished (one request). For this panel only.
    var polishTranslation = false
    /// 0 system, 1 AI, 2 AI + polish
    var translateMode: Int { useSystemTranslation ? 0 : (polishTranslation ? 2 : 1) }
    func setTranslateMode(_ mode: Int) {
        polishTranslation = mode == 2
        translationEngineOverride = mode == 0
        Store.defaults.set(mode, forKey: "gb_translate_mode")       // the picker is always visible, so the choice is kept
        run()
    }

    func translateAndPolish() {
        polishTranslation = true
        translationEngineOverride = false      // needs the AI engine
        run()
    }
    func toggleTranslationEngine() {
        translationEngineOverride = !useSystemTranslation
        run()
    }

    // MARK: limits

    func fittingParagraphs(_ text: String) -> Int {
        var total = 0, n = 0
        for p in text.components(separatedBy: "\n") {
            if total + (p as NSString).length > 3000 { break }
            total += (p as NSString).length + 1
            if !p.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        }
        return max(1, n)
    }

    func processFirstParagraphs(_ n: Int) {
        guard var cap = capture else { return }
        var kept: [String] = [], count = 0
        for p in cap.text.components(separatedBy: "\n") {
            if !p.trimmingCharacters(in: .whitespaces).isEmpty { if count == n { break }; count += 1 }
            kept.append(p)
        }
        cap.text = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        cap.editability = .readOnly       // partial result: copy only (§2.7)
        paragraphLimitNote = L.t("只处理了前 \(n) 段，结果只能复制", "Only the first \(n) paragraph(s) were processed; the result can only be copied")
        capture = cap
        run(skipLimit: true)
    }

    // MARK: consent (§7.4)

    func allowAPI(always: Bool) {
        guard let e = engine else { return }
        if always, let b = capture?.app?.bundleID { var a = state.apiAllowedApps; a[e.id + "|" + b] = true; state.apiAllowedApps = a }
        run(consentGiven: true)
    }

    func refuseAPI() {
        if let local = state.localEngine { engineOverride = local.id; run() }
        else {
            phase = .failed(Failure(message: L.t("没有发送。翻译照常可用；也可以在设置 → AI 里配一个本机模型。", "Not sent. Translation still works, or set up a local model in Settings → AI."), action: .openSettings))
        }
    }

    // MARK: result

    var finalText: String {
        if operation == .translate || changes.isEmpty { return output }
        return WordDiff.apply(changes, to: capture?.text ?? "")
    }

    var acceptedCount: Int { changes.filter(\.accepted).count }

    var recommendation: Recommendation? {
        guard phase == .done, let cap = capture, !output.isEmpty || finish != .complete else { return nil }
        var ch = checks
        // §2.4: undoing every failing change clears rule 2
        if operation != .translate, !changes.isEmpty {
            ch = Checks.run(original: cap.text, result: finalText, operation: operation, protectedWords: state.protectedWords)
        }
        let full = cap.leading + finalText + cap.trailing
        return GrammarBuddyKit.recommend(RecommendInput(
            capture: cap, profile: profile, operation: operation, checks: ch, finish: finish, leftPanel: leftPanel,
            resultIsMultiline: full.contains("\n"), canInsertBelow: canInsertBelow))
    }

    var canInsertBelow: Bool {
        guard let cap = capture else { return false }
        if cap.via == .word { return true }
        return cap.via == .accessibility && cap.range != nil && (handle?.element != nil || handle?.inProcess != nil || qaSimulated)
    }

    func toggle(_ i: Int) {
        guard changes.indices.contains(i) else { return }
        changes[i].accepted.toggle()
        focusedChange = i
        confirmArmed = false
        let c = changes[i]
        _ = c
        Announcer.say(changeLabel(i), high: false)
    }

    func changeLabel(_ i: Int) -> String {
        let c = changes[i]
        var s = L.t("第 \(i + 1) 处，共 \(changes.count) 处：", "Change \(i + 1) of \(changes.count): ")
        switch c.kind {
        case .replace: s += L.t("\(c.removed) 改为 \(c.inserted)", "\(c.removed) to \(c.inserted)")
        case .insert: s += L.t("加上 \(c.inserted)", "add \(c.inserted)")
        case .delete: s += L.t("删除 \(c.removed)", "delete \(c.removed)")
        }
        if c.flags.contains(.protected) { s += L.t("，保护内容", ", protected item") }
        s += c.accepted ? L.t("，已采用", ", accepted") : L.t("，未采用", ", not accepted")
        return s
    }

    var doneAnnouncement: String {
        let opName = OpNames.name(operation)
        var s: String
        if operation == .translate { s = L.t("\(opName)完成", "\(opName) done") }
        else if changes.isEmpty { s = L.t("\(opName)完成，模型没有找到要改的地方", "\(opName) done, the model found nothing to change") }
        else { s = L.t("\(opName)完成，\(changes.count) 处修改", "\(opName) done, \(changes.count) change\(changes.count == 1 ? "" : "s")") }
        if let r = recommendation {
            s += L.t("。回车：\(ActionNames.name(r.enter))", ". Return will \(ActionNames.name(r.enter))")
            if let why = r.enterReason { s += L.t("。", ". ") + why }
        }
        return s
    }

    // MARK: actions

    func perform(_ action: PanelAction, confirmed: Bool = false) async {
        guard let rec = recommendation, let cap = capture else { return }
        let text = finalText
        switch action {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            note = ResultNote(text: L.t("已复制，原文没有改动", "Copied. The original is unchanged"))
            log("copy")
        case .replace, .trackedChange:
            if case .unavailable(let why) = rec.putBack {
                note = ResultNote(text: why); return
            }
            if case .available(let cs) = rec.putBack, !cs.isEmpty, !confirmed, !confirmArmed {
                confirmArmed = true
                let msg = (rec.confirmText ?? "") + (state.shortcutsOn ? L.t("。再按一次 ⌘⏎ 确认", ". Press ⌘⏎ again to confirm") : L.t("。再点一次「替换」确认", ". Click Replace again to confirm"))
                note = ResultNote(text: msg)
                return
            }
            confirmArmed = false
            if cap.via == .word { await writeWord(cap) } else { await replace(cap, text: text) }
        case .insertBelow:
            await insertBelow(cap, text: text)
        }
    }

    private func writeWord(_ cap: Capture) async {
        guard let h = handle else { return }
        if qaSimulated {
            log("word.trackedChange \(acceptedCount) changes")
            note = ResultNote(text: L.t("已替换 \(acceptedCount) 处（QA 模拟，没有真的写入 Word）", "Replaced \(acceptedCount) place(s) (QA simulation, Word not touched)"), undo: true)
            didWrite = true
            return
        }
        let r = await WordBridge.writeTracked(changes, capture: cap, handle: h)
        note = ResultNote(text: r.message, undo: r.ok)
        didWrite = r.ok
        if r.ok { lastWordWrite = (changes, (finalText as NSString).length) }
    }

    func undoWord() async {
        guard let cap = capture, let h = handle, let w = lastWordWrite else {
            if qaSimulated { note = ResultNote(text: L.t("已撤销本次修改（QA 模拟）", "Undid this change (QA simulation)")); log("word.undo") }
            return
        }
        let ok = await WordBridge.rejectRevisions(capture: cap, handle: h, newLength: w.newLength)
        note = ResultNote(text: ok ? L.t("已撤销本次修改", "Undid this change") : L.t("没能完全撤销（文字之后又变了），可以在 Word 里按 ⌘Z", "Couldn't undo all of it (the text changed afterwards); press ⌘Z in Word"))
        lastWordWrite = nil
    }

    func copyChangeList() {
        let lines = changes.filter(\.accepted).map { "\($0.removed) → \($0.inserted)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        note = ResultNote(text: L.t("已复制 \(lines.count) 条修改清单", "Copied a list of \(lines.count) change(s)"), undo: note?.undo ?? false)
    }

    private func replace(_ cap: Capture, text: String) async {
        let newFull = cap.leading + text + cap.trailing
        let oldFull = cap.leading + cap.text + cap.trailing
        if qaSimulated {
            let how = cap.via == .accessibility && profile.writer != .paste ? "accessibility" : "paste"
            log("replace via \(how): \(newFull)")
            if how == "accessibility" {
                Toast.show(L.t("已替换，⌘Z 可撤销（QA 模拟）", "Replaced. ⌘Z to undo (QA simulation)"))
                onClose?()
            } else {
                Toast.show(L.t("已粘贴。位置不对请按 ⌘Z（QA 模拟）", "Pasted. Press ⌘Z if it landed in the wrong place (QA simulation)"))
                if cap.editability == .unknown, let b = cap.app?.bundleID, !state.assumeEditableApps.contains(b), !state.askAssumeEditable.contains(b) {
                    state.askAssumeEditable.append(b)
                }
                onClose?()
            }
            return
        }
        if let tv = handle?.inProcess, let r = cap.range {
            if (tv.string as NSString).length >= NSMaxRange(r), (tv.string as NSString).substring(with: r) == oldFull {
                tv.insertText(newFull, replacementRange: r)
                Toast.show(L.t("已替换，⌘Z 可撤销", "Replaced. ⌘Z to undo"))
                onClose?()
            } else {
                note = ResultNote(text: L.t("原文已经变了，没有替换。可以复制结果", "The original changed, so nothing was replaced. You can copy the result"))
            }
            return
        }
        if cap.via == .accessibility, profile.writer != .paste, let h = handle, let r = cap.range {
            let res = await WriteBack.axReplace(handle: h, range: r, oldFull: oldFull, newFull: newFull)
            switch res {
            case .verified:
                Toast.show(L.t("已替换，⌘Z 可撤销", "Replaced. ⌘Z to undo"))
                onClose?(); return
            case .unverified:
                note = ResultNote(text: L.t("写了，但没法确认。请检查原文是否已经改好", "Written, but it couldn't be confirmed. Please check the original")); return
            case .notApplied(let why) where why != "unchanged":
                note = ResultNote(text: why + L.t("。可以复制结果", ". You can copy the result")); return
            default: break   // confirmed unchanged → paste
            }
        }
        guard let h = handle else { return }
        await onYieldKeyboard?()
        let res = await WriteBack.paste(newFull, handle: h, unknownEditability: cap.editability == .unknown)
        if case .notApplied(let why) = res {
            onReclaimKeyboard?()
            note = ResultNote(text: why + L.t("。只能复制", ". Copy only"))
        } else {
            Toast.show(L.t("已粘贴。位置不对请按 ⌘Z", "Pasted. Press ⌘Z if it landed in the wrong place"))
            if cap.editability == .unknown, let b = cap.app?.bundleID, !state.assumeEditableApps.contains(b), !state.askAssumeEditable.contains(b) {
                state.askAssumeEditable.append(b)
            }
            onClose?()
        }
    }

    private func insertBelow(_ cap: Capture, text: String) async {
        guard rec(insert: true) else { return }
        if qaSimulated {
            log("insertBelow: \(text)")
            Toast.show(L.t("已插入到原文下方，⌘Z 可撤销（QA 模拟）", "Inserted below the original. ⌘Z to undo (QA simulation)"))
            onClose?(); return
        }
        if cap.via == .word, let h = handle {
            let ok = await WordBridge.insertBelow(text, handle: h)
            note = ResultNote(text: ok ? L.t("已插入到原文下方", "Inserted below the original") : L.t("没能插入，可以复制结果", "Couldn't insert; you can copy the result"))
            return
        }
        if let tv = handle?.inProcess, let r = cap.range {
            let ns = tv.string as NSString
            let nl = ns.rangeOfCharacter(from: .newlines, options: [], range: NSRange(location: NSMaxRange(r), length: ns.length - NSMaxRange(r)))
            let at = nl.location == NSNotFound ? ns.length : nl.location
            tv.insertText("\n" + text, replacementRange: NSRange(location: at, length: 0))
            Toast.show(L.t("已插入到原文下方，⌘Z 可撤销", "Inserted below the original. ⌘Z to undo"))
            onClose?(); return
        }
        guard let h = handle, let r = cap.range else { return }
        let res = await WriteBack.axInsertBelow(handle: h, range: r, text: text)
        if res == .verified { Toast.show(L.t("已插入到原文下方，⌘Z 可撤销", "Inserted below the original. ⌘Z to undo")); onClose?() }
        else { note = ResultNote(text: L.t("没能插入，原文没有动。可以复制结果", "Couldn't insert; the original is unchanged. You can copy the result")) }
    }

    private func rec(insert: Bool) -> Bool {
        guard recommendation?.insertBelow == true else {
            note = ResultNote(text: L.t("这里不能插入到原文下方", "Inserting below isn't available here"))
            return false
        }
        return true
    }

    func log(_ s: String) { qaLog.append(s); QAHarness.shared.log("panel: " + s) }
}

enum OpNames {
    static func name(_ op: TextOperation) -> String {
        switch op {
        case .fix: return L.t("改错", "Fix")
        case .polish: return L.t("润色", "Polish")
        case .translate: return L.t("翻译", "Translate")
        case .tone: return L.t("语气", "Tone")
        }
    }
    static func tone(_ t: Tone) -> String {
        switch t {
        case .formal: return L.t("正式", "Formal")
        case .casual: return L.t("口语", "Casual")
        case .friendly: return L.t("友好", "Friendly")
        case .concise: return L.t("简洁", "Concise")
        case .academic: return L.t("学术", "Academic")
        }
    }
}

enum ActionNames {
    static func name(_ a: PanelAction) -> String {
        switch a {
        case .replace: return L.t("替换", "replace")
        case .trackedChange: return L.t("替换", "replace")
        case .insertBelow: return L.t("插入到原文下方", "insert below")
        case .copy: return L.t("复制", "copy")
        }
    }
}

/// VoiceOver announcements (§3).
enum Announcer {
    @MainActor static func say(_ raw: String, high: Bool) {
        let s = raw.replacingOccurrences(of: "⌘⏎", with: L.t("Command 回车", "Command-Return"))
            .replacingOccurrences(of: "⌥⏎", with: L.t("Option 回车", "Option-Return"))
            .replacingOccurrences(of: "⏎", with: L.t("回车", "Return"))
        guard let el = NSApp.keyWindow ?? NSApp.windows.first else { return }
        NSAccessibility.post(element: el, notification: .announcementRequested, userInfo: [
            .announcement: s, .priority: (high ? NSAccessibilityPriorityLevel.high : .low).rawValue])
        QAHarness.shared.log("announce: " + s)
    }
}
