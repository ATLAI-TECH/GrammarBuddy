# 佐藤健二（kenji）— 原型试用 Round 5

人物：失明的软件工程师，日语母语、英语工作。只用键盘和 VoiceOver，从不用鼠标。在 Terminal 写 git commit message，在 VS Code 写英文文档，在邮件里写英文和日文。

判断依据：`events.log` 里的 `announce:`（会念出来的话）、`state.json`，以及只读核对 `GrammarBuddy/Panel/PanelView.swift`、`PanelController.swift`、`PanelModel.swift`、`App/OnboardingView.swift`、`App/EngineSetup.swift`。截图只当作旁边一位明眼同事帮我看了一眼。QA 目录 `/tmp/gbqa/kenji`。

## 结论（评分 4/10；现在这个样子我不会每天用）

面板的键盘模型本身是对的：面板一出现就拿到键盘，⏎ / ⌘⏎ / Esc / ⌘W / ⌘Q / ⌘H 的行为和设计一致，完成时会念出「改错完成，N 处修改，回车是复制，因为……」，↑ ↓ 加空格能逐处听、逐处撤回。这些正是我最需要的，比我现在「复制到网页工具 → 再读一遍 → 再粘回去」好得多。

但有三件事让我现在不敢用：

1. 结果出来之后按 ⌘R 重试，或者按 ⌘1–⌘4 换操作，**App 直接崩溃**（K5-01）。我两次都复现了。对我来说重试和换润色是天天要按的键，而崩溃时屏幕阅读器什么也不会念，我只会发现面板没了。
2. 日文邮件用「润色」和「语气」，模型把整封信**翻成了英文**，念出来的却只是「检查没通过」，听不出是语言变了（K5-02）。
3. 好几处状态变化是**不念的**：取消之后反而念「改错完成，1 处修改」（K5-03）；写回失败、没有读到选区、没有辅助功能权限，这些都不念（K5-05、K5-06）。对我来说，不念就等于没发生。

引导用 VoiceOver 大概能走完，但第 4 步有个陷阱：选好本机模型以后按 ⏎ 是「继续」，模型**没有保存**，第 5 步告诉我「还没有 AI」（K5-04）。

## 我的任务和过程

### 任务 1：第一次打开，全键盘走引导（含第 5 步改错 → ⏎ 替换）

| 步骤 | 我做了什么 | 看到 / 听到什么 | 我理解吗，接下来会怎么想 |
|---|---|---|---|
| 启动 | `--launch --fresh` | 引导窗口出现（`01-start-0.png`）。`state.json`：`keyWindow: none`、`appIsActive: false`。 | 由 `open -n` 从后台启动，App 没能抢到前台，这多半是测试环境的问题。真实双击启动时应该会激活（代码里有 `NSApp.activate`）。我先用 `focus`（相当于 ⌘Tab 切过去）。 |
| 第 1 步 语言 | `key:tab` ×3 | 截图上看不到焦点环（`03-tab1`、`04-tab2`）；两个语言下拉框没有拿到焦点。 | 这台机器没有开「键盘导航」，Tab 只停在文本框上，这算系统约定。真实的我开着 VoiceOver，可以用 VO 键走到下拉框（Picker 带标签，会念「你的母语……，English，弹出式按钮」）。默认值是 English + 简体中文，**我要的是日语 + 英语**。测试接口不能点下拉框，所以这一步我没法改，后面的翻译方向都按中英走。 |
| | `key:return` | 进入第 2 步。**没有任何播报**。 | 按 ⏎ 前进是好的。但换步时什么也不念，VoiceOver 的光标还停在「继续」按钮上，我得自己往回找新内容。 |
| 第 2 步 试翻译 | Tab 若干次 | Tab 到第 4 次才进入示例文字框（`type:` 返回 ok 才证明拿到了焦点），前面几次停在看不见的位置。 | 能到，但不知道自己在哪。 |
| | `select:all; hotkey:translate` | 第一次弹出的是输入模式「No selected text was found」（`10-translate-1`）。查下来是另一个评审的实例抢了前台，本进程读选区那条路没走到。重试一次以后正常（`11-translate-1`）。播报：「Translate done. Return will copy because Can't confirm this place is editable, so ⏎ copies」。 | 翻译对了：Our experiments show that this method is better than the previous method in most cases.。但播报**不包含译文本身**，我要用 VO 走过 4 个操作标签、去向、关闭、语言条、原文，才能听到译文。「because … so ⏎ copies」这句话重复了，而且 ⏎ 会被念成符号名。 |
| | `key:cmd+return` ×2 | 第 1 次念「Formatting may be lost … Press ⌘⏎ again to confirm」。第 2 次面板底栏变成「The original app is no longer in front. Copy only」，**没有念**（`12-cmdenter-readonly`）。 | 示例框是只读的，按理 ⌘⏎ 应该不可用，可面板上 ⌘⏎ 和 ⌥⏎ 都给了。确认以后失败了，失败也不念。我会以为替换成功了。 |
| | `key:escape` | 面板关闭，焦点回到引导窗口（排除别的实例抢焦点之后确认过）。 | 好。 |
| 第 3 步 权限 | ⏎ | 「Allowed」（这台机器已经授权）。 | 看得懂。 |
| 第 4 步 选 AI | `tab tab space` | 什么也没选上（`18-step4-space`）。两张卡片是 `.plain` 样式的按钮，没开键盘导航时 Tab 到不了。 | 开着 VoiceOver 时 VO+空格可以按下卡片，但按下以后卡片**没有「已选」状态**（没有 `.isSelected`），下面展开的内容也不念。 |
| | 只好 `click:` 本机卡片，用来证明这一步只能用鼠标 | 出现「LM Studio connected · Qwen3 14B (loaded) (recommended) · Use this model」（`19-step4-local-clicked`）。Tab ×3 到不了「Use this model」。 | |
| | `key:return` | 进入第 5 步，显示「**No AI yet**. Translation works now…」（`21-step5-noengine`）。`engines: []`。 | **陷阱**：⏎ 是「继续」，不是「用这个模型」。我以为确认了，其实没保存。 |
| | 第 5 步按 ⏎、Esc、⌘W | 都没有反应。「完成」不是默认按钮。 | 被困在窗口里，只能 VO 找「完成」或「上一步」。 |
| | 用鼠标点「上一步」→ 卡片 →「Use this model」 | 已配置 LM Studio · qwen3-14b，回到第 5 步（`23-step5`）。 | |
| 第 5 步 试改错 | `focus; select:all; hotkey:fix` | 0.5 秒时 `panelIsKey: true`。约 2 秒后念「Fix done, 4 changes」（`24-fix-result-1`；第一次跑撞上抢焦点，⏎ 变成了复制；重跑后 ⏎ = replace）。 | ⏎ 是替换时什么也不说，我得自己猜。我更希望也念「回车是替换」。 |
| | `↓ ↓ 空格 ↑ 空格 空格 ↓ ↓ ↓` | 念：「Change 2 of 4: reason to reasons」→「Change 3 of 4: work to works」→「…，reverted」→「Change 2 of 4 …」→「…，reverted」→「…，accepted」→「Change 3 of 4: work to works」（**没说它已撤回**）→「Change 4 of 4 …」→ 再按 ↓ 仍然是「Change 4 of 4」（`26-diff-reverted`）。 | 能逐处听、逐处撤回，这是最好的部分。问题有三个：第一下 ↓ 直接跳到第 2 处，第 1 处从来没念过；移动时不念这一处的采用状态；到了最后一处也不提示。 |
| | `↑ 空格 ⏎` | 念「Replaced. ⌘Z to undo」，示例文字变成 There are three reasons why this approach works better than the previous one [12].（`27-after-replace`）。 | 成功。 |
| | `cmd+z` | 文字没有撤回。 | App 没有「编辑」菜单（`LSUIElement`，代码里没有 mainMenu），⌘Z 在自己的窗口里多半无效。不过测试接口发键也绕过了菜单，不能百分之百确定。 |

**第一次成功要几步**：语言 ⏎ → 翻译 ⏎ → 权限 ⏎ → 第 4 步（必须用 VO 或鼠标按卡片和「Use this model」，⏎ 是陷阱）→ 选中 → ⌃⌘G → ⏎。键盘按下 8–10 次，但中间有一处必然会踩坑。

### 任务 2：Terminal 改 commit message（`simulate:terminal`）

- 原文：`git commit -m "fix teh bug in the parser wich crash on empty input"`
- 打开后 0.5 秒 `panelIsKey: true`，好。
- 念：「Fix done, 2 changes. Return will copy because This app is read-only (a terminal), so results are copied」（`30-terminal`）。这句话很清楚。
- ⌘⏎：念「This app is read-only (a terminal), so results are copied」。好。
- ⏎：念「Copied. The original is unchanged」，剪贴板里是改好的整行。面板留着。
- Esc、⌘W、⌘Q、⌘H 各试一次：都只关面板，App 还在。符合设计。
- 然后按 ⌘R 想重试 → **App 崩溃**（K5-01，崩溃报告 `GrammarBuddy-2026-11-15-074904.ips`，`PanelView.swift:454`）。

### 任务 3：VS Code 里的 Markdown 文档（JSON 构造，via clipboard）

```
## Configuration

To enable the cache, set `cache.enabled` to `true` in the `config.yaml`. The cache are stored under `~/.cache/gb` and it expire after 24 hour.
See the [setup guide](https://example.com/docs/setup) for more detail, and run `npm run build` before you commits.
```

- 念：「Fix done, 4 changes. Return will copy because Can't confirm this place is editable, so ⏎ copies」（`40-vscode`）。
- 代码、链接、路径都没有动，好。
- 原文默认展开，底下有两行小字：「Please don't click elsewhere while this runs…」和「If you didn't select anything, this is the whole line at the cursor」。我听得到，有用。
- ↑ ↓ 空格逐处撤回：念「Change 1 of 3: are to is」…「Change 3 of 3: commits to commit，reverted / accepted」，正常。
- ⌘D 切换视图正常，没有崩溃。
- 差异视图里**空行没有了**（标题和段落挤在一起），只是显示问题，结果文本里空行还在。
- ⌘⏎ 没能测：别的评审实例总在抢前台，面板每次都被判定为「You left the panel while it was working」，⌘⏎ 变成不可用。这一判定本身念得很清楚。但要注意：面板完成时念的是「can't confirm editable」，后来原因变成「left the panel」，**这次变化没有播报**。

### 任务 4：日文邮件（です・ます混用）

```
田中様

お世話になっております。佐藤です。
先日の打ち合わせの資料を送ります。修正点は3つある。まず、テストの準備に以外と時間がかかっていて、リリースが一週間遅れる見込みだ。次に、予算の件ですが、来週までに確認します。
ご確認の程、よろしくお願いします。
```

（`com.apple.mail`，accessibility，editable，rich，`range:true`）

- **改错**：只改了「以外→意外」，念「Fix done, 1 changes. Return will copy because Replacing here would lose formatting…」（`50-ja`）。「ある」「だ」的常体混用没有动。⏎ 复制，⌥⏎ 插到下方，⌘⏎ 要确认丢格式，都对。
- 按 ⌘2 换润色 → **App 崩溃**（K5-01，`GrammarBuddy-2026-11-15-074841.ips`）。
- 重启以后直接用 `op:polish` 打开：**输出成了英文**「Mr. Tanaka, Thank you for your continued support. This is Sato. …」。念的是「Polish done, 2 changes. Return will copy because Checks failed, so ⏎ copies」，确认语是「Checks failed: 1 protected item(s) changed; Formatting in the selection will be lost」（`52-ja-polish`；截图上差异块互相重叠）。
- `op:tone`：同样是英文（「Please kindly check and confirm these points.」），播报只有「Tone done」，没说用的是哪种语气。
- 核对代码：`Prompts.system` 有 `sourceLanguage` 参数，注释写着「Round 6: polish and tone drifted into English… Name the language up front」，但 `PanelModel.run()`（第 194 行）**没有传这个参数**，所以这个修正没有生效。

### 任务 5：输入模式（`simulate:manual`）打字

- 打开后光标就在输入框里（`60-manual-typed`），好。**但没有任何播报**，「No selected text was found…」这句说明不念，我只会听到「要处理的文字，文本编辑区」。
- `type:` 第一行 → ⇧⏎ → 第二行：换行正确。
- ⏎：开始处理。念「Fix done, 3 changes. Return will copy because This text wasn't read from an app, so it can only be copied」（`61-manual-result`）。
- ↑ ↓ 空格：撤回「add be」后按 ⏎，复制的是撤回后的文字（「I will looking into it」），说明逐处撤回对复制生效。

### 任务 6：没有辅助功能权限（`simulate:noax`）

- 面板以输入模式打开，文字是「GrammarBuddy isn't allowed to read selected text yet (Accessibility permission).」（`70-noax`、`71-noax2`）。
- **完全不念**。这是我最需要听到的一句话。
- 「去授权」按钮没出现，因为这台机器其实有权限，按钮的显示条件是 `!SelectionReader.hasAccessibility`。这是测试环境造成的，不算问题。
- 有一次输入框里出现了一个多余的「?」（`70-noax`），之后没能复现。

### 补充：取消后的播报

- 打开面板 0.2–1 秒内按 Esc / ⌘W / ⌘Q / ⌘H：面板关了，但随后念「Fix done, 1 changes」。
- 处理中按 ⌘2：立刻念「Polish done, 1 changes」，`state.json` 里出现一处「删除全部原文」的改动，`phase: done`，直到新的结果出来。

## 模型结果

| 场景 | 原文 | 输出 | 对不对 | 敢不敢直接用 |
|---|---|---|---|---|
| 引导第 5 步 | Their are three reason why this approach work better then the previous one [12]. | There are three reasons why this approach works better than the previous one [12]. | 全对 | 敢 |
| 引导翻译 | 我们的实验表明…… | Our experiments show that this method is better than the previous method in most cases. | 对（系统翻译） | 敢 |
| Terminal | fix teh bug in the parser wich crash on empty input | fix the bug in the parser which crash on empty input | 漏改：crash → crashes（两次都漏） | 敢复制，但还得自己再改 |
| VS Code 第 1 次 | …cache are… expire after 24 hour… before you commits | is / expires / hours / commit | 全对，代码和链接没动 | 敢 |
| VS Code 第 2、3 次 | 同上 | is / expires / commit，**漏了 hours** | 同样的输入结果不稳定 | 要逐处听 |
| 手动输入 | the deploy are blocked… CI job fail… I will looking into it | is / failed / will be looking | 全对 | 敢 |
| 日文改错 | 以外と時間がかかって；…3つある。…見込みだ。 | 意外と；常体没动 | 错字改对了；です・ます混用没改（「改错」不管文体也说得过去，但商务邮件里这就是错） | 只敢用这一处 |
| 日文润色 | 整封日文 | 整封**英文** | 错，严重 | 绝对不敢 |
| 日文语气 | 整封日文 | 整封**英文** | 错，严重 | 绝对不敢 |

## 优点

1. 面板一出现就是 key window（打开后 0.5 秒 `panelIsKey: true`），不用找焦点，直接按 ⏎ / ↑ ↓。手动输入模式下光标直接在输入框里。
2. 完成播报会说明 ⏎ 为什么不是替换（「回车是复制，因为这是终端」「……因为替换会丢格式」），⌘⏎ 不可用时按下去会念原因，第一次 ⌘⏎ 会念确认语。这正是我判断「敢不敢按」需要的信息。
3. 差异视图里 ↑ ↓ 加空格能逐处听、逐处撤回，播报「Change 3 of 4: work to works，reverted」，撤回会影响替换和复制的结果。
4. Esc、⌘W、⌘Q、⌘H 都只关面板，不会退出 App，也不会传给原 App。在引导里关掉面板后，焦点回到引导窗口。
5. Terminal 里绝不替换，⏎ 就是复制，播报说得明白。
6. 改错时代码、链接、路径、引用编号都没被动。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 | 截图 |
|---|---|---|---|---|---|
| K5-01 | P0 | `PanelView.swift:454` `ChangeChip.body` | 有改动的结果显示出来以后，按 ⌘R 或 ⌘1–⌘4 → App 崩溃，`Array index out of range`（`run()` 先把 `changes = []`，旧的 `ChangeChip` 还在用 `m.changes[index]` 取值）。两次复现：`simulate:terminal; wait:10; key:cmd+r`，以及日文改错后 `key:cmd+2`。崩溃报告 `GrammarBuddy-2026-11-15-074841.ips`、`-074904.ips`，同一时段还有另外 3 份同样的报告。 | `ChangeChip` 里先检查下标是否有效，或者按 id 取改动；重跑前先切换视图状态。 | — |
| K5-02 | P0 | `PanelModel.run()` 第 194 行；§6.5 跑偏检查 | 日文邮件用润色或语气 → 整封译成英文。播报只说「Checks failed」，确认语是「1 protected item(s) changed」，听不出语言变了。连按两次 ⌘⏎ 就会把日文邮件换成英文。`Prompts.system(sourceLanguage:)` 已经有了，但没有传进去。 | 把检测到的源语言传给 `Prompts.system`；跑偏检查加「输出语言和原文不同」，并在播报和确认语里直接说「结果变成了英文」。 | `52-ja-polish.png` |
| K5-03 | P1 | `PanelModel.run()` 第 238 行 | 取消（Esc / ⌘W / ⌘Q / ⌘H）以后仍然念「Fix done, 1 changes」；处理中按 ⌘2 立刻念「Polish done, 1 changes」，并且短暂出现一处「删除全部原文」的改动、`phase: done`。原因是循环结束后调 `complete()` 时没有检查 `Task.isCancelled`。历史记录可能也会多一条空结果。 | `complete()` 之前检查是否已取消；取消的任务不写状态、不播报。 | — |
| K5-04 | P1 | `OnboardingView.swift` 第 4 步、`EngineSetup.swift` `LocalCard` | 选了「这台 Mac 上的模型」、看到「Qwen3 14B (loaded) (recommended)」后按 ⏎ → 是「继续」，模型没有保存，第 5 步显示「No AI yet」。两张卡片没有「已选」状态；没开键盘导航时 Tab 到不了卡片和「Use this model」；第 5 步 ⏎ / Esc / ⌘W 都没反应。 | 选了卡片、有可用模型时，⏎ 就是「用这个模型并继续」（或者「继续」时自动保存）；卡片加 `.isSelected`；第 5 步把「完成」设为默认按钮；每一步换页时播报标题。 | `19-step4-local-clicked.png`、`21-step5-noengine.png` |
| K5-05 | P1 | `PanelModel.swift` 多处 `note = …` | 很多结果条不播报：「原文已经变了」（567）、「写了但没法确认」（578）、`notApplied`（580、589，实测「The original app is no longer in front. Copy only」不念）、「这里不能插入」（624）、插入下方的结果（605、619）、Word 撤销（535）、复制修改清单（543）。另外推荐的原因变化（变成「left the panel」）也不念。 | 统一用一个 `setNote(_:)`，同时播报；设计 §3 写的是「动作执行后：结果条的那句话，高优先级」。 | `11-translate-1.png` |
| K5-06 | P1 | `PanelModel.start()` 输入模式 | 没有选中文字、没有辅助功能权限时，面板打开不念原因（§2.9 和 §3 都要求出错要念）。 | 打开输入模式时用高优先级播报 `inputReason`。 | `70-noax.png`、`60-manual-typed.png` |
| K5-07 | P1 | `PanelView.swift` `DiffText`、`PanelController` | 差异视图是一个词一个 `Text` 的 FlowLayout，VoiceOver 要一个词一个词走；没有整段的可访问文本（§3「差异视图的可访问文本用文字描述」）。代码里没有把 VO 焦点放到结果区。翻译完成的播报不含译文。只能读代码判断，没有真 VO 验证。 | 给结果区一个整段的 `accessibilityValue`（改后全文）；面板出现后把 VO 焦点放到结果区；改动做成真正的可访问列表。 | `24-fix-result-1.png` |
| K5-08 | P2 | `PanelController.swift` 第 221–222 行 | ↑ ↓ 移动时不念这一处是采用还是撤回；初始焦点在第 1 处但不念，第一下 ↓ 直接到第 2 处；到头不提示；英文字符串里混了全角「，」。 | 移动时念完整标签（含状态）；打开后第一下 ↓ 先念第 1 处，或者完成播报后接着念第 1 处；到头时念「最后一处」。 | `26-diff-reverted.png` |
| K5-09 | P2 | `PanelModel.doneAnnouncement` | 「Return will copy because Can't confirm this place is editable, so ⏎ copies」重复、大小写不对、⏎ 被念成符号；⏎ 是替换时什么都不说；「1 changes」语法错；语气不说是哪种。 | 播报用单独的句子（不带 ⏎ 符号）；⏎ = 替换时也念「回车替换」。 | — |
| K5-10 | P2 | `OnboardingView.swift` | 换步不播报；第 5 步说明是「click a change to undo it」，没有提 ↑ ↓ 和空格；默认语言是中英，我在测试接口里改不了，用 VO 应该能改。 | 换步时播报标题；说明里写上键盘操作。 | `07-step2-tab.png`、`23-step5.png` |
| K5-11 | P2 | App 没有主菜单 | 替换后提示「⌘Z to undo」，在引导示例框里 ⌘Z 没有撤回。测试接口绕过了菜单分发，不完全确定。 | 给自己的窗口加一个隐藏的「编辑」菜单，或者在文本框里自己处理 ⌘Z。 | `27-after-replace.png` |
| K5-12 | P2 | 引导第 2 步，本进程读取 | 只读示例框给了 ⌘⏎ 替换和 ⌥⏎ 插到下方；确认以后失败（「original app no longer in front」），也不念。第一次判断是「can't confirm editable」，第二次是「not editable」，可能受别的实例抢焦点影响。 | 本进程读取时按 `isEditable` 走第 1 条规则。 | `11-translate-1.png` |
| K5-13 | P2 | `DiffText` 布局 | 空行不显示（Markdown 标题后、「田中様」后）；整句改写时差异块互相重叠。 | FlowLayout 连续的换行要留出空行高度；整段替换显示成上下两块。 | `40-vscode.png`、`52-ja-polish.png` |

## 测不了的部分会不会让我担心

- **真 VoiceOver**：最担心。设计 §3 的前提「VoiceOver 会不会跟到非前台 App 的 key 面板上」没有验证。如果 VO 光标不跟过来，面板的键盘虽然在，但我听不到结果，只能靠播报。偏偏 K5-05、K5-06、K5-07 说明播报目前还不够。
- **写回别的 App**：Terminal 只复制，我不担心。VS Code、Slack 走粘贴，我担心粘贴的位置不对，而我看不见。设计里「⌘Z 可撤销」对我很重要，但目前在自己的窗口里 ⌘Z 都没生效（K5-11）。
- **剪贴板方式**：VS Code 里选区会经过剪贴板。我用剪贴板历史工具，会担心文字留在里面。引导第 3 步说得很清楚，这一点是好的。
- **测试环境干扰**：同时有 4 个实例在抢前台，所以 `leftPanel` 常被置为 true，剪贴板路径下的 ⌘⏎ 没能实测。我自己还误开过一次重复的实例（不加 `--fresh` 再 `--launch` 时旧实例还活着），两个进程抢同一个 `cmd` 文件，那一轮的数据已作废并重测。
- 速度：在这台 M5 Pro 24 GB 上，qwen3-14b 处理短句约 2 秒，处理整封邮件约 10–15 秒，可以接受。
