// SettingsView.swift
// Settings (design §2.11): General, Languages, Writing, AI, Privacy.

import SwiftUI
import GrammarBuddyKit

enum SettingsTab: String, CaseIterable, Hashable { case general, languages, writing, ai, privacy }

struct SettingsView: View {
    @State var selection: SettingsTab
    @State private var setup = EngineSetup()
    @Bindable private var state = AppState.shared
    @State private var newProtected = ""
    @State private var newLocalOnly = ""

    var body: some View {
        TabView(selection: $selection) {
            general.tabItem { Label(L.t("通用", "General"), systemImage: "gearshape") }.tag(SettingsTab.general)
            languages.tabItem { Label(L.t("语言", "Languages"), systemImage: "globe") }.tag(SettingsTab.languages)
            writing.tabItem { Label(L.t("写作", "Writing"), systemImage: "pencil") }.tag(SettingsTab.writing)
            ai.tabItem { Label("AI", systemImage: "cpu") }.tag(SettingsTab.ai)
            privacy.tabItem { Label(L.t("隐私", "Privacy"), systemImage: "hand.raised") }.tag(SettingsTab.privacy)
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 500)
    }

    var general: some View {
        Form {
            Toggle(L.t("选中文字后显示「改错 / 翻译」按钮", "Show a Fix / Translate button after selecting text"), isOn: Binding(
                get: { SelectionWatcher.shared.enabled }, set: { SelectionWatcher.shared.enabled = $0 }))
            Text(L.t("用鼠标选中文字（拖选或双击）后，旁边出现一个小按钮，点一下开始。只在你点击后才读取和发送文字。",
                     "After you select text with the mouse (drag or double-click), a small button appears next to it; click to start. Text is read and sent only when you click."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle(L.t("实时标记错误：在你打字的地方直接画下划线", "Live check: underline mistakes where you type"), isOn: Binding(
                get: { LiveChecker.shared.enabled }, set: { LiveChecker.shared.enabled = $0 }))
            Text(L.t("停止输入约 1 秒后检查，点有下划线的词可以采用或忽略。只用本机模型（内置模型优先），不会把你正在写的文字自动发给任何 API。已验证：TextEdit、Word、Chrome 里的输入框。备忘录、邮件、Pages、Safari，以及 Slack、Obsidian 这类 App 按同样的办法工作，还没有逐个验证。密码框、密码管理器、终端里不会工作。",
                     "Checks about a second after you stop typing; click an underlined word to accept or ignore. Uses only a local model (built-in first) and never sends what you're writing to an API. Verified in TextEdit, Word and text areas in Chrome. Notes, Mail, Pages, Safari and apps like Slack and Obsidian work the same way but haven't each been verified. Never in password fields, password managers or terminals."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(L.t("采用建议的键（卡片打开时）", "Key that accepts a suggestion (while a card is open)"), selection: Binding(
                get: { Store.defaults.string(forKey: LiveChecker.acceptKeyKey) ?? "return" }, set: { Store.defaults.set($0, forKey: LiveChecker.acceptKeyKey) })) {
                Text(L.t("⏎ 回车（⇥ 跳过）", "⏎ Return (⇥ skips)")).tag("return")
                Text(L.t("⇥ Tab（→ 跳过，⏎ 留给 App）", "⇥ Tab (→ skips, ⏎ stays with the app)")).tag("tab")
            }
            LabeledContent(L.t("下一条建议", "Next suggestion"), value: "⌃⌘J")
            LabeledContent(L.t("改错", "Fix"), value: "⌃⌘G")
            LabeledContent(L.t("翻译", "Translate"), value: "⌃⌘T")
            if let p = state.hotkeyProblem { Text(p).foregroundStyle(.red) }
            Text(L.t("改快捷键的界面还没做（原型）。", "Changing shortcuts isn't built yet (prototype).")).font(.caption).foregroundStyle(.secondary)
            Picker(L.t("界面语言", "Interface language"), selection: $state.uiLanguage) {
                Text(L.t("跟随系统", "Follow the system")).tag("")
                Text("English").tag("en")
                Text("简体中文").tag("zh")
            }
            Text(L.t("改界面语言后，重新打开窗口生效。", "Reopen windows to apply.")).font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }

    var languages: some View {
        Form {
            Section(L.t("我的语言（第 1 种和第 2 种互译）", "My languages (1st and 2nd translate into each other)")) {
                ForEach(Array(state.myLanguages.enumerated()), id: \.offset) { i, code in
                    Picker(i == 0 ? L.t("第 1 种（母语）", "1st (native)") : L.t("第 \(i + 1) 种", "No. \(i + 1)"), selection: Binding(
                        get: { code },
                        set: { var l = state.myLanguages; l[i] = $0; state.myLanguages = l })) {
                        ForEach(LanguageDirectionHelpers.choices, id: \.self) { Text(LanguageDirection.displayName($0)).tag($0) }
                    }
                }
                HStack {
                    Button(L.t("再加一种", "Add a language")) { state.myLanguages.append("es") }
                    if state.myLanguages.count > 2 { Button(L.t("去掉最后一种", "Remove the last")) { state.myLanguages.removeLast() } }
                }
            }
            Section(L.t("翻译", "Translation")) {
                Toggle(L.t("用 AI 翻译（默认用系统翻译，在这台 Mac 上）", "Translate with AI (default: system translation, on this Mac)"), isOn: $state.translateWithAI)
                Toggle(L.t("合并硬换行（从 PDF 复制的文字）", "Join hard line breaks (text copied from PDFs)"), isOn: $state.joinHardWraps)
            }
        }.formStyle(.grouped)
    }

    var writing: some View {
        Form {
            Section(L.t("保护词表：不要改也不要翻译（区分大小写）", "Protected words: never change or translate (case-sensitive)")) {
                ForEach(state.protectedWords, id: \.self) { w in
                    HStack { Text(w); Spacer(); Button(L.t("删除", "Remove")) { state.protectedWords.removeAll { $0 == w } } }
                }
                HStack {
                    TextField(L.t("例如 CRISPR-Cas9", "e.g. CRISPR-Cas9"), text: $newProtected)
                    Button(L.t("添加", "Add")) {
                        let w = newProtected.trimmingCharacters(in: .whitespaces)
                        if !w.isEmpty && !state.protectedWords.contains(w) { state.protectedWords.append(w) }
                        newProtected = ""
                    }
                }
                Text(L.t("系统翻译不读这个表；用 AI 翻译时会写进提示词。", "System translation ignores this list; AI translation includes it in the prompt.")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L.t("语气", "Tone")) {
                Picker(L.t("上次用的语气", "Last tone"), selection: Binding(get: { state.lastTone ?? .formal }, set: { state.lastTone = $0 })) {
                    ForEach(Tone.allCases, id: \.self) { Text(OpNames.tone($0)).tag($0) }
                }
            }
        }.formStyle(.grouped)
    }

    var ai: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if state.engines.count > 1 {
                    Picker(L.t("现在用的", "In use"), selection: Binding(get: { state.activeEngine?.id ?? "" }, set: { state.activeEngineID = $0 })) {
                        ForEach(state.engines) { e in Text(e.name + " · " + e.model).tag(e.id) }
                    }
                } else if let e = state.activeEngine {
                    LabeledContent(L.t("现在用的", "In use"), value: e.name + " · " + e.model)
                } else {
                    Text(L.t("还没有配置 AI。翻译照常可用；改错、润色、语气需要一个 AI。", "No AI set up. Translation works; Fix, Polish and Tone need an AI.")).foregroundStyle(.secondary)
                }
                GroupBox { BuiltInCard(s: setup).padding(6) }
                GroupBox { APICard(s: setup).padding(6) }
                if state.engines.contains(where: { $0.id == "api" }) {
                    Button(L.t("删除 API 配置", "Remove the API setup")) { setup.removeAPI() }
                }
                GroupBox { LocalCard(s: setup).padding(6) }
                GroupBox { AppleIntelligenceRow(s: setup).padding(6) }
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("这些 App 里只用本机的模型", "Only use the local model in these apps")).font(.headline)
                        Text(L.t("即使当前选的是 API，在这些 App 里也只用本机模型；本机没有可用模型就不处理。适合写合同、论文草稿的 App。",
                                 "Even when an API is selected, these apps use only the local model; with none available, nothing is sent. Good for contracts and drafts."))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        ForEach(state.localOnlyApps, id: \.self) { b in
                            HStack { Text(appName(b)); Spacer(); Button(L.t("删除", "Remove")) { state.localOnlyApps.removeAll { $0 == b } } }
                        }
                        Menu(L.t("添加正在运行的 App", "Add a running app")) {
                            ForEach(runningApps, id: \.self) { b in Button(appName(b)) { if !state.localOnlyApps.contains(b) { state.localOnlyApps.append(b) } } }
                        }.fixedSize()
                    }.padding(6)
                }
                if !state.apiAllowedApps.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.t("已允许发给 API 的 App", "Apps allowed to send to the API")).font(.headline)
                            ForEach(state.apiAllowedApps.keys.sorted(), id: \.self) { k in
                                HStack { Text(appName(String(k.split(separator: "|").last ?? ""))); Spacer()
                                    Button(L.t("取消允许", "Revoke")) { var a = state.apiAllowedApps; a.removeValue(forKey: k); state.apiAllowedApps = a } }
                            }
                        }.padding(6)
                    }
                }
            }.padding(4)
        }
    }

    var privacy: some View {
        Form {
            Toggle(L.t("历史记录（只在内存里，最近 20 条，退出就清空）", "History (memory only, last 20, cleared on quit)"), isOn: $state.historyEnabled)
            Toggle(L.t("从不使用剪贴板方式", "Never use the clipboard method"), isOn: $state.neverUseClipboard)
            Text(L.t("在 Slack、Chrome 等 App 里我们靠模拟 ⌘C 读取，选中的文字会短暂出现在系统剪贴板里，剪贴板管理器可能记下它。打开这个开关后，这些 App 里读不到文字，只能在面板里输入。",
                     "In Slack, Chrome and similar apps we read by simulating ⌘C, so the selection briefly sits on the clipboard where clipboard managers may record it. With this on, those apps can't be read; type in the panel instead."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LabeledContent(L.t("辅助功能权限", "Accessibility permission"), value: SelectionReader.hasAccessibility ? L.t("已允许", "Allowed") : L.t("未允许", "Not allowed"))
            if !SelectionReader.hasAccessibility { Button(L.t("打开系统设置…", "Open System Settings…")) { Permissions.requestAccessibilityPrompt(); Permissions.openAccessibility() } }
            LabeledContent(L.t("不处理的 App", "Apps never processed"), value: L.t("密码管理器（1Password、Bitwarden、钥匙串访问…）", "Password managers (1Password, Bitwarden, Keychain Access…)"))
            LabeledContent(L.t("只读的 App", "Read-only apps"), value: L.t("终端类（Terminal、iTerm2…）", "Terminals (Terminal, iTerm2…)"))
        }.formStyle(.grouped)
    }

    var runningApps: [String] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleIdentifier).sorted()
    }

    func appName(_ bundle: String) -> String {
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) { return FileManager.default.displayName(atPath: u.path).replacingOccurrences(of: ".app", with: "") }
        return bundle
    }
}
