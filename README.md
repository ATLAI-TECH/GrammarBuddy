<div align="center">

# GrammarBuddy

**Open-source AI writing buddy for macOS: fix grammar, polish your writing, and translate text in any app.**

**English** · [中文](#中文)

</div>

> **Status: working prototype, not released.** There is no app to download yet. A prototype runs from source (see [`CONTRIBUTING.md`](CONTRIBUTING.md)); reading and writing other apps has not been verified on real apps yet. Design: [`docs/DESIGN.md`](docs/DESIGN.md). Model results: [`docs/MODELS.md`](docs/MODELS.md).

GrammarBuddy is a menu-bar tool. Select text in any app, press a shortcut, and a small panel appears next to it:

| Action | What it does |
|---|---|
| **Fix** | Corrects grammar, spelling and punctuation. Leaves your wording alone. |
| **Polish** | Rewrites so the text reads clearly and naturally. |
| **Translate** | Translates into your other language. |
| **Tone** | Formal, casual, friendly, concise, academic. |

You see the result first, with every change highlighted, and decide whether to put it back. In Microsoft Word the changes are written as tracked changes, so you can accept or reject them one by one.

## Where your text goes

You choose the AI. Both ways are fully supported:

- **Your own model**: LM Studio or Ollama running on your Mac. Your text stays on the machine.
- **An API**: paste an API key for an OpenAI-compatible service. Faster and uses no memory; your text is sent to that service.

Translation uses the engine built into macOS. Apple Intelligence can be used where available.

- The panel always shows where the current request is being sent, and marks API requests in orange.
- With an API, GrammarBuddy asks once per app before sending text from it, and you can list apps that must only ever use the local model.
- No GrammarBuddy account, no telemetry. API keys are stored in the macOS Keychain.

One thing to know: in apps that do not expose their text through the macOS accessibility API (Slack, Chrome, VS Code and other Electron or Chromium apps), GrammarBuddy reads your selection by simulating ⌘C. The selected text passes through the system clipboard for a moment, and a clipboard manager may record it. This can be turned off.

## What it is not

It does not draw underlines in other apps as you type. It checks text when you ask.

## Plan

| Version | Contents |
|---|---|
| 0.1 | The four actions, change-by-change review, Word tracked changes. Fix and Polish need an API key or a local model app such as LM Studio. |
| 0.2 | Long documents, explanations for each change, custom actions. |
| 1.0 | Built-in model download: no other app to install. |

## Documents

| | |
|---|---|
| [`docs/DESIGN.md`](docs/DESIGN.md) | The design (Chinese) |
| [`docs/DEVLOG.md`](docs/DEVLOG.md) | What has been done, results, pitfalls and next steps (Chinese) |
| [`docs/INVESTIGATION.md`](docs/INVESTIGATION.md) | Feasibility tests done before the design |
| [`docs/MODELS.md`](docs/MODELS.md) | Local models tested on six languages |
| [`docs/review/`](docs/review/) | Four rounds of simulated-user review and how each issue was handled |
| [`qa/model-eval/`](qa/model-eval/) | The multilingual test corpus, prompts and raw model outputs |

## License

[MIT](LICENSE) © 2026 AtLAI-tech

---

## 中文

**开源的 macOS 写作搭子：改语法、润色、翻译，在任意 App 里都能用。**

> **状态：能运行的原型，还没有发布。** 现在还没有可以下载的 App。原型可以从源码运行（见 [`CONTRIBUTING.md`](CONTRIBUTING.md)）；读写其他 App 还没有在真实 App 里验证。设计见 [`docs/DESIGN.md`](docs/DESIGN.md)，模型实测见 [`docs/MODELS.md`](docs/MODELS.md)。

GrammarBuddy 是一个菜单栏工具。在任意 App 里选中文字，按一个快捷键，旁边弹出一个小面板：

| 操作 | 做什么 |
|---|---|
| **改错** | 改语法、拼写、标点，不动你的用词。 |
| **润色** | 把句子改得更通顺、更地道。 |
| **翻译** | 译成你的另一种语言。 |
| **语气** | 正式、口语、友好、简洁、学术。 |

结果先给你看，每处改动都标出来，由你决定要不要放回去。在 Microsoft Word 里，修改会写成修订，可以逐条接受或拒绝。

### 你的文字去了哪里

用哪个 AI 由你选，两种都是正式支持的：

- **自己搭的**：这台 Mac 上的 LM Studio 或 Ollama。文字不出电脑。
- **API**：填一个 OpenAI 兼容服务的 API key。更快，不占内存；文字会发给那家服务。

翻译用 macOS 自带的翻译。Apple Intelligence 可用时也能选。

- 面板上每次都写明这次的文字发到了哪里，用 API 时标成橙色。
- 用 API 时，每个 App 第一次使用前会问一次；还可以列出「只许用本机模型」的 App。
- 没有 GrammarBuddy 账号，不收集数据。API key 存在 macOS 钥匙串里。

有一点要知道：有些 App 不通过 macOS 的辅助功能接口提供文字（Slack、Chrome、VS Code 等 Electron 或 Chromium 应用）。在这些 App 里，GrammarBuddy 靠模拟 ⌘C 来读选中的文字，文字会短暂经过系统剪贴板，剪贴板管理器可能把它记下来。这个方式可以关掉。

### 它不是什么

它不会在你打字时往别的 App 里画下划线。你让它检查的时候它才检查。

### 计划

| 版本 | 内容 |
|---|---|
| 0.1 | 四个操作、逐处取舍、Word 修订。改错和润色需要一个 API key，或者装一个本地模型 App（例如 LM Studio）。 |
| 0.2 | 长文档、每处改动的解释、自定义操作。 |
| 1.0 | 内置模型下载，不需要再装别的。 |

### 许可

[MIT](LICENSE) © 2026 AtLAI-tech
