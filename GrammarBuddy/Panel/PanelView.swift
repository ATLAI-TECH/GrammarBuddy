// PanelView.swift
// The floating panel (design §2.2): operation tabs, destination badge, original, diff/result, bottom bar.

import SwiftUI
import GrammarBuddyKit

struct PanelView: View {
    @Bindable var m: PanelModel
    var close: () -> Void
    var act: (PanelAction) -> Void
    var resize: (CGFloat) -> Void = { _ in }
    @State private var contentH: CGFloat = 100
    var maxContent: CGFloat = 300     // panel max 420 pt (§2.2); long translations get more room

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if m.operation == .translate && m.phase != .input { languageBar }
                    if m.capture != nil && m.phase != .input { originalRow }
                    content
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentH = $0; resize($0) }
            }
            .frame(height: min(max(contentH, 60), maxContent))
            Divider()
            footer
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity)
        .background(.regularMaterial)
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("GrammarBuddy：" + OpNames.name(m.operation))
    }

    // MARK: header

    var header: some View {
        HStack(spacing: 4) {
            ForEach(Array(TextOperation.allCases.enumerated()), id: \.element) { i, op in
                Button {
                    m.switchOperation(op)
                } label: {
                    HStack(spacing: 2) {
                        Text(op == .tone && m.operation == .tone ? OpNames.tone(m.tone) : OpNames.name(op)).lineLimit(1).fixedSize()
                        if op == .tone { Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)) }
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(m.operation == op ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .fontWeight(m.operation == op ? .semibold : .regular)
                }
                .buttonStyle(.plain)
                .help("⌘\(i + 1)")
                .accessibilityLabel(OpNames.name(op) + "，⌘\(i + 1)")
                .accessibilityAddTraits(m.operation == op ? .isSelected : [])
                .popover(isPresented: op == .tone ? $m.showTonePicker : .constant(false)) { tonePicker }
            }
            Spacer(minLength: 8)
            engineBadge
            Button { close() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help(L.t("关闭（Esc）", "Close (Esc)"))
                .accessibilityLabel(L.t("关闭", "Close"))
        }
        .padding(.horizontal, 10).padding(.top, 9).padding(.bottom, 7)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())        // move the panel by its header
    }

    var tonePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L.t("选一种语气", "Choose a tone")).font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)
            ForEach(Tone.allCases, id: \.self) { t in
                Button { m.chooseTone(t) } label: {
                    HStack { Text(OpNames.tone(t)); Spacer(); if m.tone == t && m.state.lastTone != nil { Image(systemName: "checkmark") } }
                        .frame(width: 140).padding(.vertical, 3).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(10)
    }

    var engineBadge: some View {
        let b = m.badge
        return Menu {
            if m.operation == .translate {
                Button(L.t("系统翻译（在这台 Mac 上）", "System translation (on this Mac)")) { if !m.useSystemTranslation { m.toggleTranslationEngine() } }
                Button(L.t("用 AI 翻译（只这一次）", "Translate with AI (this time)")) { if m.useSystemTranslation { m.toggleTranslationEngine() } }
                Divider()
            }
            ForEach(m.selectableEngines) { e in
                Button {
                    m.engineOverride = e.id
                    if m.operation == .translate && m.useSystemTranslation { m.translationEngineOverride = false }
                    m.run()
                } label: {
                    Text(e.name + " · " + e.model + (Destination.classify(e.baseURL) == .internet ? L.t("（文字会发给 \(e.name)）", " (text is sent to \(e.name))") : ""))
                }
            }
            Divider()
            Button(L.t("AI 设置…", "AI settings…")) { AppDelegate.shared?.openSettings(tab: .ai) }
        } label: {
            Text(b.text).font(.caption).lineLimit(1).truncationMode(.middle)
                .foregroundStyle(b.leaves ? Color.orange : Color.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 190)
        .help(b.leaves ? L.t("文字会离开这台电脑", "Your text leaves this Mac") : L.t("处理的去向", "Where the text is processed"))
        .accessibilityLabel(L.t("去向：", "Destination: ") + b.text)
    }

    // MARK: language bar (§2.5)

    var languageBar: some View {
        HStack(spacing: 6) {
            Menu(LanguageDirection.displayName(m.sourceLang)) {
                ForEach(LanguageDirectionHelpers.choices, id: \.self) { c in Button(LanguageDirection.displayName(c)) { m.setSource(c) } }
            }.fixedSize()
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Menu(LanguageDirection.displayName(m.targetLang)) {
                let mine = m.state.myLanguages
                ForEach(mine + LanguageDirectionHelpers.choices.filter { !mine.contains($0) }, id: \.self) { c in
                    Button(LanguageDirection.displayName(c)) { m.setTarget(c, remember: false) }
                }
                Divider()
                Button(L.t("以后从\(LanguageDirection.displayName(m.sourceLang))都译成\(LanguageDirection.displayName(m.targetLang))", "Always translate \(LanguageDirection.displayName(m.sourceLang)) into \(LanguageDirection.displayName(m.targetLang))")) {
                    m.setTarget(m.targetLang, remember: true)
                }
            }.fixedSize()
            .help("⌘L")
            Spacer()
            if !m.state.engines.isEmpty {
                // the three ways to translate, always visible (round 7, I7-04: "translate and polish" was a link below the fold)
                Picker("", selection: Binding(get: { m.translateMode }, set: { m.setTranslateMode($0) })) {
                    Text(L.t("系统", "System")).tag(0)
                    Text("AI").tag(1)
                    Text(L.t("AI + 润色", "AI + polish")).tag(2)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(.small)
                .help(L.t("系统翻译：最快，在这台 Mac 上。AI：更准，适合专业文字。AI + 润色：译完再改成像母语者写的。", "System: fastest, on this Mac. AI: more accurate for specialised text. AI + polish: translated, then rewritten to read like a native writer."))
            }
        }
        .font(.callout)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("翻译方向", "Translation direction"))
    }

    var originalCount: String {
        let t = m.capture?.text ?? ""
        let cjk = t.unicodeScalars.filter { (0x3040...0x9FFF).contains($0.value) }.count
        if cjk > t.count / 3 { return L.t("原文（\(cjk) 字）", "Original (\(cjk) characters)") }   // G5-16
        return L.t("原文（\(m.capture?.wordCount ?? 0) 词）", "Original (\(m.capture?.wordCount ?? 0) words)")
    }

    // MARK: original (§2.2)

    var originalRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            DisclosureGroup(isExpanded: $m.showOriginal) {
                Text(m.capture?.text ?? "").textSelection(.enabled).font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
            } label: {
                Text(originalCount)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if m.capture?.via == .clipboard, case .working = m.phase {
                Text(L.t("处理期间请不要点别处，否则这次只能复制", "Please don't click elsewhere while this runs, or the result can only be copied"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if m.capture?.notes.contains(.maybeWholeLine) == true {
                Text(L.t("如果你没有选中文字，这是光标所在的整行", "If you didn't select anything, this is the whole line at the cursor"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let n = m.paragraphLimitNote { Text(n).font(.caption2).foregroundStyle(.orange) }
        }
    }

    // MARK: main content

    @ViewBuilder var content: some View {
        switch m.phase {
        case .input: inputMode
        case .askSource: askSource
        case .askConsent: askConsent
        case .tooLong(let n): tooLong(n)
        case .needsDownload: needsDownload
        case .working(let s): working(s)
        case .failed(let f): failed(f)
        case .done:
            if m.operation == .tone && m.showTonePicker && m.output.isEmpty {
                Text(L.t("先选一种语气（⌘4 再按一次也能打开这个列表）", "Choose a tone first (press ⌘4 again to open this list)")).foregroundStyle(.secondary)
            } else {
                result
            }
        }
    }

    var inputMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(m.inputReason ?? "").font(.callout).fixedSize(horizontal: false, vertical: true)
            if !SelectionReader.hasAccessibility && m.inputReason == ReadFailure.noAccessibilityPermission.message {
                Button(L.t("去授权", "Grant access")) { Permissions.openAccessibility() }
            }
            TextEditor(text: $m.manualText)
                .font(.body).frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel(L.t("要处理的文字", "Text to process"))
            HStack {
                Button(L.t("用剪贴板里的文字", "Use clipboard text")) { m.useClipboard() }
                Spacer()
                Text(L.t("⏎ 开始 · ⇧⏎ 换行", "⏎ start · ⇧⏎ new line")).font(.caption).foregroundStyle(.secondary)
                Button(L.t("开始", "Start")) { m.submitManual() }.disabled(m.manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    var askSource: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("这段文字太短或语言不明显。请确认它是什么语言：", "This text is short or its language isn't clear. Which language is it?"))
            HStack {
                Picker("", selection: $m.sourceLang) {
                    ForEach(LanguageDirectionHelpers.choices, id: \.self) { Text(LanguageDirection.displayName($0)).tag($0) }
                }.labelsHidden().frame(width: 180)
                Button(L.t("翻译", "Translate")) { m.confirmSourceAndRun() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    var askConsent: some View {
        let name = m.engine?.name ?? "API"
        return VStack(alignment: .leading, spacing: 8) {
            Label(L.t("在 \(m.appName) 里选中的文字会发给 \(name)，允许吗？", "Text you select in \(m.appName) will be sent to \(name). Allow?"), systemImage: "exclamationmark.shield")
                .foregroundStyle(.orange).font(.callout.weight(.semibold))
            Text(L.t("上面「原文」就是要发出去的内容。选择会按 App 记住，可以在设置 → AI 里改。", "The “Original” above is exactly what would be sent. Your choice is remembered per app; change it in Settings → AI."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L.t("不允许", "Don't allow")) { m.refuseAPI() }
                if m.state.localEngine != nil { Text(L.t("（改用本机模型）", "(use the local model)")).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(L.t("只这一次（⏎）", "Just this once (⏎)")) { m.allowAPI(always: false) }.keyboardShortcut(.defaultAction)
                Button(L.t("允许，在 \(m.appName) 里记住", "Always allow in \(m.appName)")) { m.allowAPI(always: true) }
            }
        }
    }

    func tooLong(_ n: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("这段文字超过了 AI 一次能处理的长度（约 3000 字符，500 个英文词或 1500 个汉字）。",
                     "This text is longer than the AI can handle at once (about 3,000 characters: 500 English words or 1,500 Chinese characters)."))
                .fixedSize(horizontal: false, vertical: true)
            Button(L.t("只处理前 \(n) 段", "Process only the first \(n) paragraph(s)")) { m.processFirstParagraphs(n) }
            Text(L.t("这时结果只能复制。系统翻译没有这个限制（最多 20000 字符）。", "The result can then only be copied. System translation has no such limit (up to 20,000 characters)."))
                .font(.caption).foregroundStyle(.secondary)
            if m.operation == .translate && !m.useSystemTranslation {
                Button(L.t("改用系统翻译整篇翻译", "Translate it all with system translation")) { m.toggleTranslationEngine() }
            }
        }
    }

    var needsDownload: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("第一次翻译 \(LanguageDirection.displayName(m.sourceLang)) → \(LanguageDirection.displayName(m.targetLang)) 需要下载系统的语言包（只需一次，之后在这台 Mac 上翻译）。",
                     "The first \(LanguageDirection.displayName(m.sourceLang)) → \(LanguageDirection.displayName(m.targetLang)) translation needs a one-time system language download. After that it runs on this Mac."))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L.t("下载语言包…", "Download…")) { m.downloadLanguages() }
                if !m.state.engines.isEmpty { Button(L.t("改用 AI 翻译", "Use AI translation")) { m.toggleTranslationEngine() } }
            }
        }
    }

    func working(_ s: Phase.Status) -> some View {
        HStack(spacing: 8) {
            if m.output.isEmpty { ProgressView().controlSize(.small) }
            switch s {
            case .reading: Text(L.t("正在读取…", "Reading…"))
            case .loadingModel: Text(L.t("正在加载模型… \(m.thinkingSeconds) 秒", "Loading the model… \(m.thinkingSeconds) s"))
            case .thinking: Text(L.t("思考中 · \(m.thinkingSeconds) 秒", "Thinking · \(m.thinkingSeconds) s"))
            case .streaming:
                if m.output.isEmpty { Text(L.t("等待模型… \(m.thinkingSeconds) 秒", "Waiting for the model… \(m.thinkingSeconds) s")) }
                else { Text(m.output).textSelection(.enabled) }
            case .translating(let n): Text(n > 1 ? L.t("正在翻译 \(n) 段…", "Translating \(n) paragraphs…") : L.t("正在翻译…", "Translating…"))
            }
            Spacer()
        }
        .foregroundStyle(m.output.isEmpty ? .secondary : .primary)
        .accessibilityElement(children: .combine)
    }

    func failed(_ f: Failure) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(f.message, systemImage: "exclamationmark.triangle").fixedSize(horizontal: false, vertical: true)
            HStack {
                switch f.action {
                case .openSettings?: Button(L.t("去设置", "Open Settings")) { AppDelegate.shared?.openSettings(tab: .ai) }
                case .openLMStudio?:
                    Button(L.t("打开 LM Studio", "Open LM Studio")) { m.openLMStudio() }
                    Button(L.t("重试", "Retry")) { m.run() }
                case .retry?: Button(L.t("重试（⌘R）", "Retry (⌘R)")) { m.run() }
                case .grantAccessibility?: Button(L.t("去授权", "Grant access")) { Permissions.openAccessibility() }
                case .chooseEngine?: if !m.state.engines.isEmpty { Button(L.t("改用 AI 翻译", "Use AI translation")) { m.toggleTranslationEngine() } }
                case .openAutomationSettings?: Button(L.t("打开「自动化」设置", "Open Automation settings")) { Permissions.openAutomation() }
                case nil: EmptyView()
                }
            }
        }
    }

    // MARK: result (§2.2)

    @ViewBuilder var result: some View {
        if m.operation == .translate {
            if m.showDiff {
                VStack(alignment: .leading, spacing: 10) {
                    let src = (m.capture?.text ?? "").components(separatedBy: "\n")
                    ForEach(Array(src.enumerated()), id: \.offset) { i, p in
                        if !p.trimmingCharacters(in: .whitespaces).isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p).font(.callout).foregroundStyle(.secondary)
                                let t = i < m.translatedParas.count ? m.translatedParas[i] : nil
                                if m.translatedParas.isEmpty {
                                    if i == src.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { Text(m.output).textSelection(.enabled) }
                                }
                                else if let t { Text(t).textSelection(.enabled) }
                                else { Text(L.t("这一段没有翻译成功，显示的是原文", "This paragraph failed to translate; showing the original")).font(.caption).foregroundStyle(.orange) }
                            }
                        }
                    }
                }
            } else {
                Text(m.output).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            if !m.state.engines.isEmpty {
                HStack(spacing: 14) {
                    if m.usesSystemTranslation {
                        Button(L.t("用 AI 再译一次", "Translate again with AI")) { m.toggleTranslationEngine() }
                    }
                    if !m.polishTranslation {
                        Button(L.t("翻译并润色（AI，读起来像母语者写的）", "Translate and polish (AI, reads like a native writer)")) { m.translateAndPolish() }
                    } else {
                        Label(L.t("已润色的译文", "Polished translation"), systemImage: "sparkle").foregroundStyle(.secondary)
                    }
                }.buttonStyle(.link).font(.caption)
            }
            if !m.checks.numberMismatch.isEmpty {
                Label(L.t("译文里的数字和原文对不上：", "Numbers differ from the original: ") + m.checks.numberMismatch.joined(separator: ", "), systemImage: "number")
                    .font(.caption).foregroundStyle(.orange)
            }
        } else if m.output.isEmpty && m.finish == .complete {
            Label(L.t("模型没有输出任何内容", "The model returned nothing"), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        } else if m.changes.isEmpty {
            Label(L.t("模型没有找到要改的地方（不等于一定没有错）", "The model found nothing to change (that doesn't guarantee there are no errors)"), systemImage: "checkmark.circle").foregroundStyle(.secondary)
            Text(m.output).foregroundStyle(.secondary).textSelection(.enabled)
        } else if m.showDiff {
            DiffText(m: m)
        } else {
            Text(m.finalText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        if let q = m.quoteNote, m.operation != .translate {
            Label(q, systemImage: "quote.opening").font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        if m.finish == .truncated {
            Label(L.t("输出不完整（被截断或太长被中断），不能放回原处，可以重试", "The output is incomplete (cut off or stopped for length); it can't be put back. Retry?"), systemImage: "scissors")
                .font(.caption).foregroundStyle(.orange)
        }
        if m.checks.failed && m.operation != .translate {
            Label(m.checks.summary, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        if m.operation == .polish || m.operation == .tone {
            Text(L.t("润色和语气会整句改写，请看过再用。", "Polish and tone rewrite whole sentences; please read before using."))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: footer (§2.2, §2.3)

    var footer: some View {
        footerBody.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { resize($0) }   // T5-11
    }

    var footerBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let n = m.note {
                HStack {
                    Text(n.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if n.undo {
                        Button(L.t("撤销本次修改", "Undo this change")) { Task { await m.undoWord() } }
                        Button(L.t("复制修改清单", "Copy change list")) { m.copyChangeList() }
                    }
                }
                .padding(.horizontal, 12).padding(.top, 6)
            } else if m.askLanding && m.phase == .done {
                HStack {
                    Text(L.t("上次在 \(m.appName) 里替换的位置对吗？对的话，以后在这里 ⏎ 直接替换。", "Did last time's replace in \(m.appName) land in the right place? If so, ⏎ will replace here from now on."))
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(L.t("对", "Yes")) { m.answerLanding(true) }
                    Button(L.t("不对", "No")) { m.answerLanding(false) }
                }.padding(.horizontal, 12).padding(.top, 6)
            } else if let r = m.recommendation, let why = r.enterReason {
                Text(why).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 6)
            }
            // one row when it fits; otherwise counter and view switch on top, actions below (L5-05)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { counter; Spacer(minLength: 8); actions; viewSwitch }
                VStack(spacing: 6) {
                    HStack { counter; Spacer(); viewSwitch }
                    HStack(spacing: 12) { Spacer(); actions }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    @ViewBuilder var counter: some View {
        if m.phase == .done, m.operation != .translate, !m.changes.isEmpty {
            Text(L.t("\(m.changes.count) 处 · 采用 \(m.acceptedCount)", "\(m.acceptedCount)/\(m.changes.count) accepted"))
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).fixedSize()
        }
    }

    @ViewBuilder var viewSwitch: some View {
        if m.phase == .done, m.recommendation != nil {
            Picker("", selection: $m.showDiff) {
                Text(m.operation == .translate ? L.t("对照", "Side by side") : L.t("差异", "Changes")).tag(true)
                Text(m.operation == .translate ? L.t("译文", "Translation") : L.t("结果", "Result")).tag(false)
            }.pickerStyle(.segmented).labelsHidden().fixedSize().help("⌘D")
        }
    }

    @ViewBuilder var actions: some View {
        if m.phase == .done, let r = m.recommendation {
            footerButton("⏎", ActionNames.name(r.enter), bold: true) { act(r.enter) }
            if r.enter != .copy { footerButton("⌘C", L.t("复制", "copy")) { act(.copy) } }
            if case .available = r.putBack, r.enter != .replace && r.enter != .trackedChange {
                footerButton("⌘⏎", m.capture?.via == .word ? L.t("写为修订", "tracked change") : L.t("替换", "replace")) {
                    act(m.capture?.via == .word ? .trackedChange : .replace)
                }
            }
            if r.insertBelow && r.enter != .insertBelow { footerButton("⌥⏎", L.t("插到下方", "below")) { act(.insertBelow) } }
            if case .unavailable = r.putBack {
                Text(L.t("⌘⏎ 不可用", "⌘⏎ unavailable")).font(.caption).foregroundStyle(.tertiary).fixedSize()
            }
        } else {
            footerButton("⌘R", L.t("重试", "retry")) { m.run() }.disabled(m.capture == nil)
            footerButton("Esc", L.t("关闭", "close")) { close() }
        }
    }

    func footerButton(_ key: String, _ title: String, bold: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(key).font(.caption.monospaced()).foregroundStyle(.secondary)
                Text(title).fontWeight(bold ? .semibold : .regular)
            }
            .lineLimit(1).fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + "，" + key)
    }
}

// MARK: diff view with per-change toggles (§2.2)

struct DiffText: View {
    @Bindable var m: PanelModel

    var body: some View {
        let original = m.capture?.text ?? ""
        let ns = original as NSString
        var pieces: [Piece] = []
        var cursor = 0
        for (i, c) in m.changes.enumerated() {
            if c.range.location > cursor {
                pieces += words(ns.substring(with: NSRange(location: cursor, length: c.range.location - cursor)))
            }
            pieces.append(.change(i))
            cursor = NSMaxRange(c.range)
        }
        if cursor < ns.length { pieces += words(ns.substring(from: cursor)) }
        return FlowLayout(spacing: 0, lineSpacing: 4) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, p in
                switch p {
                case .text(let s): Text(s).fixedSize()
                case .newline: Color.clear.frame(width: 2000, height: 0)   // forces a line break
                case .change(let i): ChangeChip(m: m, index: i)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("差异，\(m.changes.count) 处修改", "Changes, \(m.changes.count)"))
        .accessibilityValue(L.t("结果：", "Result: ") + m.finalText)     // K5-07: the whole result as one text
    }

    enum Piece { case text(String), newline, change(Int) }

    func words(_ s: String) -> [Piece] {
        var out: [Piece] = []
        for (li, line) in s.components(separatedBy: "\n").enumerated() {
            if li > 0 { out.append(.newline) }
            var cur = ""
            for ch in line {
                cur.append(ch)
                if ch == " " || ch.unicodeScalars.first.map({ $0.value >= 0x3000 }) == true { out.append(.text(cur)); cur = "" }
            }
            if !cur.isEmpty { out.append(.text(cur)) }
        }
        return out
    }
}

struct ChangeChip: View {
    @Bindable var m: PanelModel
    let index: Int

    var body: some View {
        if m.changes.indices.contains(index) { chip } // a rerun empties the list while old views still exist (K5-01)
    }

    var chip: some View {
        let c = m.changes[index]
        let focused = m.focusedChange == index
        return Button { m.toggle(index) } label: {
            HStack(spacing: 0) {
                if c.accepted {
                    if !c.removed.isEmpty { Text(c.removed.visibleWhitespaceIfOnlySpace).strikethrough().foregroundStyle(.red) }
                    if !c.inserted.isEmpty { Text(c.inserted.visibleWhitespaceIfOnlySpace).underline().foregroundStyle(.green) }
                } else {
                    Text(c.removed.isEmpty ? "⁁" : c.removed).foregroundStyle(.primary)
                        .overlay(alignment: .topTrailing) { Image(systemName: "arrow.uturn.backward").font(.system(size: 7)).foregroundStyle(.secondary).offset(x: 4, y: -4) }
                }
                if c.flags.contains(.inQuote) {
                    Image(systemName: "quote.opening").font(.system(size: 8)).foregroundStyle(.orange).padding(.leading, 1)
                }
                if c.flags.contains(.protected) {
                    Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(.orange).padding(.leading, 1)
                }
            }
            .padding(.horizontal, 1)
            .background(focused ? Color.accentColor.opacity(0.15) : (c.flags.contains(.protected) ? Color.orange.opacity(0.12) : .clear),
                        in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help(c.accepted ? L.t("点一下撤回这处修改（空格）", "Click to revert this change (Space)") : L.t("点一下重新采用（空格）", "Click to accept again (Space)"))
        .accessibilityLabel(m.changeLabel(index) + "，" + (c.accepted ? L.t("已采用", "accepted") : L.t("未采用", "not accepted")))
        .accessibilityAction(named: L.t("采用", "Accept")) { if !m.changes[index].accepted { m.toggle(index) } }
        .accessibilityAction(named: L.t("不采用", "Reject")) { if m.changes[index].accepted { m.toggle(index) } }
        .accessibilityAction(named: L.t("复制这一处", "Copy this change")) {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(m.changes[index].inserted, forType: .string)
        }
    }
}

extension String {
    var visibleWhitespaceIfOnlySpace: String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? visibleWhitespace : self
    }
}

/// Simple wrapping layout for the diff (words and change chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(width: proposal.width ?? 440, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = layout(width: bounds.width, subviews: subviews)
        for (i, p) in r.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    func layout(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var pts: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            var sz = s.sizeThatFits(.unspecified)
            let isBreak = sz.width >= 1999
            if isBreak { sz.width = 0 }
            if x > 0 && (x + sz.width > width || isBreak) { x = 0; y += lineH + lineSpacing; lineH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing
            lineH = max(lineH, isBreak ? 0 : sz.height)
            maxX = max(maxX, x)
        }
        return (CGSize(width: min(maxX, width), height: y + lineH), pts)
    }
}
