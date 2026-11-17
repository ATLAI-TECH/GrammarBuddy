# 第 5 轮：5 位模拟用户试用原型 App，共用说明

前四轮评的是设计稿和模型输出。这一轮有了能运行的原型：菜单栏 App、浮动面板、引导、设置，改错 / 润色 / 语气用这台 Mac 上 LM Studio 里的真实模型，翻译用 macOS 的系统翻译。你要扮演分配给你的人物，**真的去用它**，判断它好不好用、会不会让你放弃。

## 先读

- `docs/DESIGN.md` §1–§3（产品是什么、面板和按键）。不用读完整份设计稿，你是用户，不是评审设计的人。
- 本文的「怎么驱动 App」和「这次测不了的」。

## 怎么驱动 App

App 带一个只在 DEBUG 里的测试接口：App 自己截自己的窗口、自己给自己发按键。你通过一个脚本给它发命令。

```bash
cd <仓库目录>
Q=/tmp/gbqa/<你的代号>
qa/gbqa.sh $Q --launch --fresh            # 启动一个全新的实例（设置是空的，会弹出引导）
qa/gbqa.sh $Q "shot:01-start@all"          # 截所有窗口到 $Q/01-start-0.png …；用 Read 工具看图
qa/gbqa.sh $Q "simulate:slack; wait:6; shot:02-panel; dump"
cat $Q/state.json                          # 面板当前状态：结果、改动、⏎ 推荐什么、⌘⏎ 要确认什么、提示语
cat $Q/events.log                          # 播报（VoiceOver 会念的话）、小条提示、写回动作的记录
```

命令（完整列表在 `GrammarBuddy/QA/QAHarness.swift` 文件头）：

| 命令 | 作用 |
|---|---|
| `shot:<名字>` / `shot:<名字>@all` | 截当前目标窗口 / 所有窗口。截图是 2 倍像素，坐标要除以 2 |
| `target:<panel\|onboarding\|settings\|test>` | 之后的按键、点击、截图对着哪个窗口 |
| `key:<键>` | `return` `escape` `tab` `space` `up` `down`，或单个字符；修饰键 `cmd+` `opt+` `shift+` `ctrl+`。例：`key:cmd+return`、`key:cmd+2` |
| `type:<文字>` | 在当前焦点的输入框里输入 |
| `click:x,y` | 点窗口里的位置（点，左上角为原点，含标题栏） |
| `open:<onboarding\|settings\|settings:ai\|test>` | 打开引导、设置（可指定标签页 general / languages / writing / ai / privacy）、测试窗口 |
| `hotkey:<fix\|translate>` | 相当于按下 ⌃⌘G / ⌃⌘T。只对 App 自己的窗口有效（引导里的示例文字、测试窗口），先 `select:` 选中文字 |
| `select:<起点>,<长度>` 或 `select:all` | 在目标窗口的文本框里选中文字 |
| `simulate:<预设或 JSON>` | 模拟「在别的 App 里选中了文字并按了快捷键」，打开面板 |
| `panel:<动作>` | 面板上需要用菜单才能做的事，见下 |
| `engine:…` | 直接配置 AI（跳过引导时用）：`engine:local=qwen/qwen3-14b`、`engine:clear` |
| `set:<键>=<值>` | 改设置，例如 `set:gb_ui_language=zh` 把界面换成中文 |
| `wait:<秒>`、`dump`、`quit` | 等待；写出 `state.json`；退出 |

`simulate:` 的预设：`textedit`（可编辑的纯文本，学术英文）、`slack`、`gmail-chrome`（Chrome 里的 Gmail，带一个链接）、`word`（Word 里的一段学术英文）、`word-translate`（Word 里的一段中文）、`terminal`（终端里的 commit 命令）、`pages`（Pages 里的西班牙语新闻，带数字和引语）、`manual`（没有选中文字）、`noax`（没有辅助功能权限）。预设后面加 `+polish` / `+tone` / `+translate` 换操作，例如 `simulate:slack+tone`。也可以给 JSON 自己造场景：

```
simulate:{"app":"com.tinyspeck.slackmacgap","name":"Slack","via":"clipboard","edit":"unknown","rich":"plain","op":"fix","text":"你自己的文字"}
```

`via` 是 `accessibility`（读到了选区和位置）、`clipboard`（Chrome、Slack 这类靠模拟 ⌘C 读）、`word`；`edit` 是 `editable` / `readOnly` / `unknown`；`rich` 是 `plain` / `rich` / `unknown`；`"range":true` 表示读到了位置（才能「插入到原文下方」）。

`panel:` 动作：`tone=friendly`（formal casual friendly concise academic）、`target=es`（目标语言）、`source=fr`、`toggle=2`（撤回 / 重新采用第 2 处改动，从 0 数）、`op=polish`、`allow=always|once`、`refuse`、`first=2`（超长时只处理前 2 段）、`diff`、`retry`、`aiTranslate`、`sysTranslate`、`undoWord`、`copyList`、`leave`（模拟「处理期间点了别处」）。

**不要点 SwiftUI 的弹出菜单和下拉框**（面板右上角的去向标记、语言名、设置里的下拉框）：测试接口点它们会卡住 App 的事件循环。需要换语言、换引擎就用 `panel:` 和 `engine:`；设置里的下拉框用截图看，必要时用 `set:`。卡住了就用 `pkill -f "gb_qa_dir /tmp/gbqa/<代号>"` 只关掉自己的实例，在报告里记下，再重新 `--launch`（不加 `--fresh` 设置还在）。**不要**用 `pkill -f GrammarBuddy`，那会把别人的实例也关掉。

## 这次测不了的（不计入评分，但要在报告里说你会不会因此担心）

- **读写别的 App**：这台机器没有给测试用的 App 辅助功能权限，所以读不到 Slack、Word 里真的选区，写回也不会真的发生。`simulate:` 打开的面板里，「替换」「粘贴」「写为修订」只记进 `events.log` 和 `state.json` 的 `qaLog`，并在提示里写「QA 模拟」。**App 自己的窗口是真的**：引导第 2、5 步的示例文字和「测试窗口」（`open:test`）里，选中 → `hotkey:` → ⏎ 会真的替换。
- **API**：没有真的 API key。测 API 的人物用 `engine:api=https://api.openai.com/v1|gpt-4.1-mini|sk-qa|local` 配置一个「API」，界面按 API 显示（橙色标记、按 App 询问），但请求实际发给本机的 LM Studio。不加 `|local` 就是真的发给 OpenAI，会得到「API key 不对」，可以用来测出错的样子。
- **系统翻译的语言包下载**：会弹系统窗口，测试接口点不到。没装的语言对会显示「需要下载语言包」，到这一步为止。
- **VoiceOver**：没有真的屏幕阅读器。`events.log` 里 `announce:` 开头的行就是会念出来的话；每个控件的可访问标签要看代码（`GrammarBuddy/Panel/PanelView.swift`）。
- 机器是 M5 Pro 24 GB。你的人物如果是别的配置，速度按这台机器的实测说，并注明。
- 同时有另外 4 个评审在用同一个 LM Studio，偶尔会遇到「正在加载模型」或变慢，记下来，但不要据此给速度下结论；需要的话重试一次。

## 怎么评

1. 写下你的人物在一个真实工作日里会用它做的 4–6 个具体任务，**从第一次打开开始**（引导）。
2. 每个任务实际操作一遍，每一步截图。写：我做了什么 → 屏幕上出现什么（截图文件名）→ 我理解吗 → 接下来我会怎么想。
3. 特别留意：第一次安装到第一次成功要几步；结果对不对、敢不敢直接按 ⏎；出错时看到什么；我的文字去了哪里；和我现在用的工具比，我会不会换。
4. 看到模型改错了、漏改了，具体写出来（原文、输出、应该是什么）。

## 规则

- 只写报告和截图。不要改仓库里的代码和其他文件，不要 git commit。
- 不要操作这台 Mac 上的其他 App（Word、LM Studio、系统设置），不要改系统设置，不要退出或重启 LM Studio。
- 只用自己代号的 QA 目录和 App 实例。结束时 `qa/gbqa.sh $Q "quit"`。
- 像真实用户一样诚实，别客气，也别为了凑数报问题。原型里明说「还没做」的（比如改快捷键）不算问题，除非你的人物因此用不了。

## 报告

截图挑重要的复制到 `docs/review/round-5/shots/<代号>/`（不要全部复制），报告写到 `docs/review/round-5/<代号>.md`（中文）：

```
# <人物> — 原型试用 Round 5
## 结论（评分 X/10；一句话：现在这个样子我会不会每天用，为什么）
## 我的任务和过程（每个任务逐步写，带截图文件名）
## 模型结果（逐条：原文 / 输出 / 对不对 / 我敢不敢直接用）
## 优点（≥3，具体）
## 问题清单
| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 | 截图 |
## 测不了的部分会不会让我担心
```

- P0 = 我的核心任务完成不了，或者会改坏我的文字、泄露文字；P1 = 明显影响体验或会让我放弃；P2 = 打磨。
- ID 用 `<代号首字母大写>5-序号`，例如 `L5-03`。
- 最终回复只要三样：分数、最重要的 3 个问题（带 ID）、报告路径。
