// OnboardingView.swift
// First run (design §2.10): languages → try translation → permission → choose an AI → try fix.
// A normal window; every step can be skipped; works with the keyboard only.

import SwiftUI
import AppKit
import GrammarBuddyKit

struct OnboardingView: View {
    var close: () -> Void
    @Bindable private var state = AppState.shared
    @State private var step = 0
    @State private var setup = EngineSetup()
    @State private var axGranted = SelectionReader.hasAccessibility
    @State private var aiChoice: Int? = 2      // built-in preselected   // 0 API, 1 local

    let steps = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule().fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.25)).frame(height: 4)
                }
            }.padding(.horizontal, 24).padding(.top, 18)
            Text(L.t("第 \(step + 1) 步，共 \(steps) 步", "Step \(step + 1) of \(steps)")).font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 24).padding(.top, 6)
            ScrollView {
                Group {
                    switch step {
                    case 0: languages
                    case 1: tryTranslate
                    case 2: permission
                    case 3: chooseAI
                    default: tryFix
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                if step > 0 { Button(L.t("上一步", "Back")) { step -= 1 } }
                Spacer()
                Button(step == steps - 1 ? L.t("完成", "Done") : L.t("跳过", "Skip")) { next() }
                if step < steps - 1 {
                    Button(L.t("继续", "Continue")) { next() }.keyboardShortcut(.defaultAction).disabled(!canContinue)
                }
            }.padding(16)
        }
        .frame(width: 640, height: 560)
        .onChange(of: step) { _, s in
            let titles = [L.t("你用哪些语言", "Which languages do you use"), L.t("试一下翻译", "Try translating"),
                          L.t("允许读取选中的文字", "Allow reading selected text"), L.t("选一个 AI", "Choose an AI"), L.t("试一下改错", "Try Fix")]
            Announcer.say(L.t("第 \(s + 1) 步，共 \(steps) 步：", "Step \(s + 1) of \(steps): ") + titles[s], high: true)
        }
    }

    var canContinue: Bool {
        if step == 0 { return state.myLanguages.count >= 2 && state.myLanguages[0] != state.myLanguages[1] }
        return true
    }

    func next() {
        if step == steps - 1 { state.onboardingDone = true; close(); return }
        // Round 5 L5-01: a model picked but not confirmed with "Use this model" is saved on Continue
        if step == 3 {
            if aiChoice == 2 && BuiltInModels.shared.state(setup.builtInModel) == .ready && !state.engines.contains(where: { $0.kind == .builtin }) { setup.saveBuiltIn() }
            if aiChoice == 1 && !setup.localModel.isEmpty && !state.engines.contains(where: { $0.kind == .lmstudio || $0.kind == .ollama }) { setup.saveLocal() }
            if aiChoice == 0 && setup.apiOK && !setup.apiModel.isEmpty && !state.engines.contains(where: { $0.id == "api" }) { setup.saveAPI() }
        }
        step += 1
    }

    // MARK: 1. languages

    var languages: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("你用哪些语言？", "Which languages do you use?")).font(.title2.bold())
            Text(L.t("翻译时，这两种语言互相翻译；其他语言默认译成第一种。", "These two translate into each other; other languages go into the first one."))
                .foregroundStyle(.secondary)
            langPicker(0, L.t("你的母语，或者读起来最轻松的语言", "Your native language, or the one you read most easily"))
            langPicker(1, L.t("你常用的另一种语言", "Another language you use a lot"))
            if state.myLanguages.count >= 2 && state.myLanguages[0] == state.myLanguages[1] {
                Text(L.t("两种语言不能一样。", "The two languages must differ.")).foregroundStyle(.red).font(.caption)
            }
            LangPackStatus(from: state.myLanguages.count > 1 ? state.myLanguages[1] : "en", to: state.myLanguages.first ?? "zh-Hans")
        }
    }

    func langPicker(_ i: Int, _ label: String) -> some View {
        Picker(label, selection: Binding(get: { state.myLanguages.count > i ? state.myLanguages[i] : "en" },
                                         set: { var l = state.myLanguages; while l.count <= i { l.append("en") }; l[i] = $0; state.myLanguages = l })) {
            ForEach(LanguageDirectionHelpers.choices, id: \.self) { Text(LanguageDirection.displayName($0)).tag($0) }
        }
    }

    // MARK: 2. try translation (in-process, no permission needed)

    var sample: String {
        let second = state.myLanguages.count > 1 ? state.myLanguages[1] : "en"
        switch LanguageDirectionHelpers.base(second) {
        case "zh-Hans": return "我们的实验表明，这种方法在大多数情况下都比以前的方法更好。"
        case "es": return "Nuestros resultados muestran que este método funciona mejor que el anterior en la mayoría de los casos."
        case "fr": return "Nos résultats montrent que cette méthode fonctionne mieux que la précédente dans la plupart des cas."
        case "de": return "Unsere Ergebnisse zeigen, dass diese Methode in den meisten Fällen besser funktioniert als die vorherige."
        case "ja": return "私たちの結果は、この方法がほとんどの場合に以前の方法よりも優れていることを示しています。"
        default: return "Our results show that this method works better than the previous one in most cases."
        }
    }

    var tryTranslate: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("试一下翻译", "Try translating")).font(.title2.bold())
            Text(L.t("选中下面这段文字，然后按 ⌃⌘T（Control + Command + T）。", "Select the text below, then press ⌃⌘T (Control + Command + T)."))
            DemoTextView(text: sample, editable: false).frame(height: 70)
            Text(L.t("翻译用 macOS 自带的系统翻译，不需要任何权限，也不需要 AI。", "Translation uses macOS's built-in translation. No permission or AI needed."))
                .font(.caption).foregroundStyle(.secondary)
            if state.hotkeyProblem != nil { Text(state.hotkeyProblem!).foregroundStyle(.red) }
        }
    }

    // MARK: 3. permission

    var permission: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("允许读取选中的文字", "Allow reading selected text")).font(.title2.bold())
            Text(L.t("要在别的 App 里读取和替换你选中的文字，macOS 需要你在「系统设置 → 隐私与安全性 → 辅助功能」里打开 GrammarBuddy 的开关。",
                     "To read and replace the text you select in other apps, macOS needs you to switch on GrammarBuddy in System Settings → Privacy & Security → Accessibility."))
                .fixedSize(horizontal: false, vertical: true)
            if axGranted {
                Label(L.t("已允许", "Allowed"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(L.t("打开系统设置", "Open System Settings")) { Permissions.requestAccessibilityPrompt(); Permissions.openAccessibility() }
                Text(L.t("打开开关后这里会自动变成「已允许」，不需要重启 GrammarBuddy。", "Once it's on, this turns into “Allowed” by itself; no restart needed."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            GroupBox {
                Text(L.t("在 Slack、Chrome、VS Code、Notion 这类 App 里，GrammarBuddy 靠模拟 ⌘C 读取：选中的文字会短暂经过系统剪贴板（几百毫秒后恢复），剪贴板管理器可能记下它。不想这样，可以在设置 → 隐私里关掉。",
                         "In apps like Slack, Chrome, VS Code and Notion, GrammarBuddy reads by simulating ⌘C: the selection passes briefly through the clipboard (restored after a few hundred ms), and clipboard managers may record it. You can turn this off in Settings → Privacy."))
                    .font(.caption).fixedSize(horizontal: false, vertical: true).padding(4)
            }
        }
        .task {
            while !Task.isCancelled && !axGranted {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                axGranted = SelectionReader.hasAccessibility
            }
        }
    }

    // MARK: 4. choose an AI

    var chooseAI: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("选一个 AI（改错和润色要用）", "Choose an AI (for Fix and Polish)")).font(.title2.bold())
            Text(L.t("翻译现在就能用。改错、润色、换语气需要一个 AI。推荐内置模型：不用装别的。以后可以几种都配，在面板右上角随时切换。",
                     "Translation already works. Fix, Polish and Tone need an AI. The built-in model is recommended: nothing else to install. You can add several later and switch from the panel."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                choiceCard(2, L.t("内置模型（推荐）", "Built-in (recommended)"), "cpu",
                           L.t("不用装别的，文字不出电脑，免费", "Nothing to install; text stays here; free"),
                           L.t("下载一次模型（2–8 GB），占内存", "One model download (2–8 GB); uses memory"))
                choiceCard(0, L.t("用 API", "Use an API"), "cloud",
                           L.t("最快，不占内存", "Fastest, no memory used"),
                           L.t("选中的文字会发给这家服务，按用量付费", "Selected text is sent to that service; pay per use"))
                choiceCard(1, L.t("LM Studio / Ollama", "LM Studio / Ollama"), "server.rack",
                           L.t("发送到本机的 LM Studio，不经过网络，免费", "Sent to LM Studio on this Mac, not the network; free"),
                           L.t("要占几个 GB 内存，速度看机器（这台 \(state.ramGB) GB）", "Uses a few GB of memory; speed depends on the Mac (this one: \(state.ramGB) GB)"))
            }
            if aiChoice == 2 { BuiltInCard(s: setup) { step += 1 } }
            if aiChoice == 0 { APICard(s: setup) { step += 1 } }
            if aiChoice == 1 { LocalCard(s: setup) { step += 1 } }
            if !state.engines.isEmpty {
                Label(L.t("已配置：", "Set up: ") + state.engines.map { $0.name + " · " + $0.model }.joined(separator: "，"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.callout)
            }
        }
    }

    func choiceCard(_ i: Int, _ title: String, _ icon: String, _ plus: String, _ minus: String) -> some View {
        Button { aiChoice = i } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon).font(.headline)
                Label(plus, systemImage: "plus.circle").font(.caption).foregroundStyle(.green)
                Label(minus, systemImage: "minus.circle").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).stroke(aiChoice == i ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: aiChoice == i ? 2 : 1))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    // MARK: 5. try fix

    var tryFix: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("试一下改错", "Try Fix")).font(.title2.bold())
            if state.engines.isEmpty {
                Text(L.t("还没有配置 AI。翻译现在就能用，改错随时可以在设置 → AI 里开启。", "No AI yet. Translation works now; turn on Fix any time in Settings → AI."))
            } else {
                Text(L.t("选中下面这句（里面有错），按 ⌃⌘G。结果出来后按 ⏎ 替换，或者点某处修改撤回它。",
                         "Select the sentence below (it has mistakes) and press ⌃⌘G. When the result appears, press ⏎ to replace, or click a change to undo it."))
                    .fixedSize(horizontal: false, vertical: true)
                DemoTextView(text: "Their are three reason why this approach work better then the previous one [12].", editable: true).frame(height: 70)
                Text(L.t("这里是纯文本，所以 ⏎ 是替换。在 Gmail、Slack 这类不能确认格式的地方，⏎ 会是复制，⌘⏎ 才替换。",
                         "This is plain text, so ⏎ replaces. Where formatting can't be confirmed (Gmail, Slack…), ⏎ copies and ⌘⏎ replaces."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LangPackStatus: View {
    let from: String, to: String
    @State private var st: TranslationState?

    var body: some View {
        Group {
            switch st {
            case .ready?: Label(L.t("这对语言的系统翻译已经装好", "System translation for this pair is installed"), systemImage: "checkmark.circle").foregroundStyle(.green)
            case .needsDownload?:
                HStack {
                    Label(L.t("需要先下载一次语言包", "Needs a one-time language download"), systemImage: "arrow.down.circle")
                    Button(L.t("下载…", "Download…")) { SystemTranslator.download(from: from, to: to) { _ in Task { st = await SystemTranslator.status(from: from, to: to) } } }
                }
            case .unsupported?: Label(L.t("系统翻译不支持这对语言，可以用 AI 翻译", "System translation doesn't support this pair; AI translation can"), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            case nil: ProgressView().controlSize(.small)
            }
        }
        .font(.callout)
        .task(id: from + to) { st = await SystemTranslator.status(from: from, to: to) }
    }
}

/// A real NSTextView so the shortcut can read and write it in-process.
struct DemoTextView: NSViewRepresentable {
    var text: String
    var editable: Bool
    var rich: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSTextView.scrollableTextView()
        let tv = sv.documentView as! NSTextView
        tv.string = text
        tv.isEditable = editable
        tv.isSelectable = true
        tv.isRichText = rich
        tv.font = .systemFont(ofSize: 14)
        tv.textContainerInset = NSSize(width: 6, height: 6)
        tv.allowsUndo = true
        sv.borderType = .bezelBorder
        tv.setAccessibilityLabel(L.t("示例文字", "Sample text"))
        return sv
    }

    func updateNSView(_ v: NSScrollView, context: Context) {}
}

struct TestWindowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("纯文本（⏎ 应该是替换）", "Plain text (⏎ should replace)")).font(.caption)
            DemoTextView(text: "Their are three reason why the flc-3 mutant flower earlier then Col-0 under long days (16 h light / 8 h dark), as previously reported [12, 15].", editable: true)
            Text(L.t("富文本（⏎ 应该是复制）", "Rich text (⏎ should copy)")).font(.caption)
            DemoTextView(text: "Please review the attached report before friday. Thanks for you're help.", editable: true, rich: true)
            Text(L.t("只读（只能复制）", "Read-only (copy only)")).font(.caption)
            DemoTextView(text: "Los resultados muestran que el método funciona mejor en 1.400 muestras.", editable: false)
        }.padding(16).frame(minWidth: 560, minHeight: 380)
    }
}
