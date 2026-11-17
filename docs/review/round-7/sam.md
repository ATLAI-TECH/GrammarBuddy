# Sam（十年 macOS 开发，全键盘） — 用着顺不顺 Round 7

## 结论（评分 4/10；一句话：现在不会开着它写东西）

- **Safari 里一条标记都没标出来**（三次尝试，见下）。所以实时标记的速度、准确度、卡片、采用后的文字，我**一项都没能实际跑**。键盘流程的各个分支是**读代码**得出的，不是跑出来的；每条我都标了「实测」还是「读代码」。
- 读代码找到一个我认为是 P0 的问题：采用之后被替换的词处于**选中**状态，而卡片在写回期间是关着的，这时再按一次 ⏎（连按、长按、或者最后一条之后多按一下）会进到 App 里，**把刚采用的词换成一个换行**。
- 「⏎ 采用」这个方向我同意，但现在的实现还不能默认打开：修饰键判断写错了（⌘⏎ 也会采用）、事件拦截会泄漏、失败时没有任何提示。
- 面板里的润色和「翻译并润色」是好的，代码、URL、版本号都没动。

## 我试了什么（宿主、文字、每一步和看到的结果，带时间）

宿主：Safari（测试开始时 Safari **没有在运行**，`qa/host.sh safari` 在后台把它冷启动了）。前台一直是 Chrome，没有切过前台。引擎按说明配成 `LM Studio / qwen/qwen3-14b` + `gb_live_use_configured=true`。

测试文字 `/tmp/gbtest/sam-1.txt`：7 句技术文档，约 15 处错（主谓一致、`wich`、`dont`、`an other`、`must to check`），带 `` `KeyTap` ``、`` `CGEvent.tapCreate(tap:place:…)` ``、`` `stop()` ``、一个 developer.apple.com 的长 URL、`2.4.1`、`macOS 14.5`、`0.5 s`。

| 时间 | 做了什么 | 结果 |
|---|---|---|
| 20:44:48 | `qa/host.sh safari sam-1.txt`，`live:app=com.apple.Safari; live:on`，之后每 1.5 秒 `dump`，共 49 秒 | **0 条标记**。`liveValue` 是 `file:///private/tmp/gbtest/host-204448.html`（43 个字符）：焦点在 Safari 的**地址栏**，不在页面的输入框。2.6 秒时状态是「0 suggestion(s), 1 sentence(s) queued」，也就是这个 URL 被当成一句话送去检查了 |
| 20:45 | `axtree:com.apple.Safari`（只读） | 焦点元素是工具栏里的 `AXTextField`；窗口里当时还没有 `AXWebArea` |
| 20:46 | 按说明重试：`open -g -b com.apple.Safari`，再看 14 秒 | 还是 0 条，`liveValue` 还是那个 URL |
| 20:46:53 | 换一段短文字 `sam-2.txt`（3 句），再 `qa/host.sh safari`，看 45 秒 | 2.3 秒时又把新 URL 排队查了一次，之后 `liveValue` 变空，**0 条标记**，状态为空 |
| 20:47 | `axtree`、`axprobe`（见「测不了的」里的说明） | 页面已加载：`AXWebArea → AXTextArea value=218`（就是我的文字）。但 **`FOCUSED: none`**，`AXFocusedUIElement` 返回 -25212（kAXErrorNoValue） |
| 20:48 | `live:next; live:key=return/tab/escape/a; live:open=0; live:z` | `card: none`，提示「No suggestions here」；四个键都是 `used=false`（卡片没开时 ⏎ 确实不被拦）；`overlay window #0 follows #0`（没有下划线层可看） |
| 20:49 | 面板：`simulate` 润色 sam-1 全文 | 19 处改动，全部正确，见下 |
| 20:50 | 面板：中文技术段落 → 翻译 → `panel:polishTranslate` | 见下 |

**Safari 标不出来的原因（实测 + 读代码）**

`LiveChecker.focusedTextElement`（LiveChecker.swift:181–195）只问 App 元素的 `kAXFocusedUIElementAttribute`。Safari 在后台时：

- 原生控件（地址栏）有焦点 → 能读到，于是地址栏被当成文本框检查；
- 网页内容有焦点 → 返回 kAXErrorNoValue，函数返回 nil，`tick()` 走 `clear()`，什么都不做。

输入框本身在辅助功能树里是有的（`AXTextArea value=218`）。Chrome 后台能测、Safari 不能，差别就在这一个属性上。**Safari 在前台时是否正常，我没法测**（不能切前台），所以我不能说「Safari 不支持」，只能说「测试接口的后台方式在 Safari 上不成立，前台没验证」。设置页里写着 Safari「按同样的办法工作」，这句现在没有依据。

## 七个问题的回答

1. **等多久**：测不了。Safari 里没有出现过标记。
2. **标得对不对**：实时标记测不了。能说的只有一条反面发现：Safari 的地址栏被当成了正文（S7-03）。
3. **键盘流程**（读代码，LiveChecker.swift:362–418；卡片没开时的四个键是实测）：
   - **⌃⌘J 选哪条**（`reviewNext`，:386）：选「起点 ≥ 光标位置」的第一条，没有就回到全文第一条。后果：光标**在一个被标记的词里面或紧跟在它后面**时（刚打完错词最常见的位置），这条被跳过，去了后面那条；光标后面没有标记时跳回文首第一条，而不是离光标最近的上一条。没有「上一条」的键。
   - **最后一条之后 ⏎**（`accept` → `openNext`，:394）：如果前面有用 ⇥ 跳过的，会**绕回第一条被跳过的**，没有任何「已经到头、从头开始」的提示；全部处理完才提示「All suggestions here are done」并关卡片。
   - **⇥ 到末尾**（:410）：绕回第一条，永远转圈；只剩一条时按 ⇥ 是直接关卡片（和 Esc 一样），没有提示。
   - **Esc**：关卡片，键不进 App。符合直觉。
   - **卡片开着按普通键**：`closeCard()` 后返回 false，键照常进 App。设计是对的。但写回期间按的键不会关卡片（`handleKey` 开头的 `card.isVisible` 已经是 false），下一张卡片照样弹出来。
   - **带修饰键的 ⏎**：**⌘⏎、⌃⏎、⌥⏎ 都会采用，并且被吃掉**。`case kVK_Return, kVK_ANSI_KeypadEnter where plain:` 里的 `where` 只约束最后一个模式（小键盘 Enter）。我用同样写法的 10 行脚本实测：`Return + Cmd → ACCEPT`，`KeypadEnter + Cmd → pass through`，编译器对这一行本身也会给警告。另外 `plain` 不看 Shift：⇧⏎ 采用，⇧⇥ 是「下一条」而不是「上一条」。
   - **⏎ 这个设计**：见最后一节。
4. **采用之后**：测不了。读代码有一个大问题（S7-01）。
5. **段落改写**（实测，面板）：sam-1 全文润色，19 处，全对：`install→installs`、`are→is`、`found→find`、`wich→which`、`dont→don't`、`must to check→must check` 等。三段行内代码、URL、`2.4.1`、`14.5`、`0.5 s` 一个字符没动。差异看得懂，我敢按 ⏎。小毛病：`an other → another` 被拆成「删 an」和「other→another」两处，单独撤回其中一处会留下 `an another` 或 `other app`；`thread, it is` 的逗号拼接没改；长 URL 在面板里超出右边被截断（截图 `/tmp/gbqa/sam/01-polish-0.png`）。
6. **翻译并润色**（实测）：系统翻译有三处硬伤：`return to nil`（应为 return nil）、`recommended card`（建议卡片）、`0.5 seconds late for the actual measurement`。「翻译并润色」全部改对：`pass the key press through unchanged`、`or it will return nil`、`the delay has been measured to be approximately 0.5 seconds`。代码、URL、版本号都在。技术文档只该用后者。
7. **整体**：面板像一个靠谱的同事。实时标记我在 Safari 里没见到。会让我关掉它的是 S7-01（改坏文字）和 S7-05/07（一个我看不见、会留在系统里的键盘拦截）。

## 模型的建议逐条评（原词 → 新词：对 / 错 / 没必要）

实时标记没有产出，下面是面板润色的 19 处：

| 改动 | 评价 |
|---|---|
| install→installs、are→is、get→gets、enable→enables、pass→passes、return→returns、float→floats、fire→fires、are→is（末句） | 对 |
| found→find、wich→which、was→were、dont→don't、删 `to`（must to check） | 对 |
| changing anything → make any changes | 对（before you changing 确实要改） |
| switch→switches | 可以，`switched` 更贴合过去时 |
| 删 `an` + other→another | 对，但应该是一处改动 |
| 删 `the`（the Accessibility permission） | 没必要 |

没有碰代码、URL、版本号，没有把对的改错。

## KeyTap 风险评估（读 LiveChecker.swift:686–720）

| 场景 | 会怎样 | 依据 |
|---|---|---|
| `tapCreate` 返回 nil | 静默返回。卡片照样写着「⏎ 采用」，但 ⏎ 进了 App，变成换行 | :706 的 `guard … else { return }`，没有日志、没有改卡片文案 |
| 拦截超时（主线程卡住） | 系统停用拦截并把这次按键放行（⏎ 变换行），回调收到通知后重新启用。没有记录 | :695。主线程上有每 0.5 秒一轮的辅助功能调用，单次超时 0.3 秒，标记多时一轮可以很长 |
| 关卡片之后 | **拦截没有真的移除**。`stop()` 只停用并摘掉 run loop 源，没有 `CFMachPortInvalidate`。实测 `CGGetEventTapList`：priya 的实例（pid 45849）留下 6 个、marta 的（pid 51015）留下 3 个已停用的 keyDown 拦截，每开关一次卡片多一个 | :714–719 + 实测 |
| 焦点离开文本框时卡片开着 | `tick()` 走 `clear()`，只 `card.hide()`，**不调 `closeCard()`**：拦截保持启用，`activeMark` 不清。之后全系统每次按键都同步经过 GrammarBuddy 的主线程，直到下一次开关卡片 | :88–94、:113、:130 |
| 输入法组字时按 ⏎ | 拦截在会话最前面，比输入法先拿到 ⏎。正常情况下开始打字就关了卡片，不会抢。会抢的情况：组字中按 ⌃⌘J；或者采用后的写回空档里开始打拼音，随后下一张卡片弹出来，这时 ⏎（想上屏英文）被拿去采用。代码里没有任何「正在组字」的判断，而 Safari 的输入框有 `AXTextInputMarkedRange` 可以查 | :404、:427 |
| 卡片开着切到别的 App 再按 ⏎ | 鼠标点过去：全局监听关卡片，没问题。⌘Tab：如果拦截收得到这次按键就走 default 分支关掉（我没法实测收不收得到）。别的 App 自己跳到前台（弹窗、通知）：最长 0.5 秒内卡片还在、拦截还在，这时按 ⏎ 会被吃掉，并改到后台那个 App 的文字里 | :63 的 0.5 秒轮询是唯一的收尾 |
| 密码框 | 好的。`AXSecureTextField` 不取（:191），Secure Input 打开时整个停掉（:113），系统此时也不会把按键交给拦截 | 读代码 |
| 长按 ⏎ | 不看 autorepeat 标志，重复的 ⏎ 有的采用下一条，有的落进空档变成换行 | :700 |

## 窗口层级（`live:z`）

没有标记就没有下划线层，`live:z` 只给出 `overlay window #0 follows #0`，所以贴合关系我没看到。读代码（:515–544）的判断：

- 贴在目标窗口上一层的做法是对的，比全屏浮动层好得多。
- 下划线的屏幕坐标缓存 2 秒，只有滚轮事件会让它失效（:70、:334）。**键盘滚动（Page Down、方向键）和拖动、缩放窗口都不会**，下划线会在旧位置停留最多约 2.5 秒。全键盘用户天天碰到。
- 是否画出来只看标记中心在不在输入框的框内（:306），不看输入框是否被网页自己的滚动裁掉。Safari 里输入框滚到工具栏下面时，下划线可能画在工具栏上。未验证。
- 卡片是 `popUpMenu` 层级、所有桌面可见（:623），不跟宿主窗口走。下划线已经不会穿透别的 App 了，卡片还会。

## 播报（events.log 里的 `announce:`）

我自己的日志里只有 `No suggestions here` 和面板的两类（`Polish done, 19 changes. Return will replace`、`Translate done. Return will replace`）。卡片的播报我读的是别人和开发时留下的日志（`/tmp/gbqa/keys`、`marta`、`priya`，只读）：

- 正常的：`Suggestion: cost to costs. Return accepts, Tab goes to the next, Escape closes`。内容够用，但每一条都重复整句按键说明，连过十条很啰嗦，说明应该只在第一条说。
- **坏的**：`Suggestion: to  to .`（出现 6 次）和 `Suggestion:  to  a.`。删除、插入、只改空格的建议，播出来是空的。卡片上有「（删除）」的写法，播报没有用。
- 缺的：第几条 / 共几条；采用是否成功；绕回第一条；「全部处理完」只走提示条。
- `Announcer.say` 把通知发在 GrammarBuddy 自己的窗口上（PanelModel.swift:746），而这时前台是别的 App。VoiceOver 念不念，我没法验证。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| S7-01 | P0（读代码，未能运行） | WriteBack.swift:46；LiveChecker.swift:405、:422 | 采用成功后 `axReplace` 把**新词选中**；同时卡片已 `hide()`，`handleKey` 因 `card.isVisible == false` 放行。写回要 ≥30 ms 再加一轮 `tick()`（Word 是 250 ms 以上）。这段时间里的 ⏎，以及最后一条采用完、卡片关掉后多按的那一下 ⏎，都进到 App，把选中的新词换成换行。复现：TextEdit 里 ⌃⌘J 后快速连按或长按 ⏎，看 `liveValue` | 写回后把光标折叠到新词末尾（最好还原用户原来的光标）；写回期间拦截保持「忙」状态，吃掉 ⏎/⇥；忽略 autorepeat；最后一条之后再吃 ⏎ 约 300 ms |
| S7-02 | P1 | LiveChecker.swift:181 | Safari 在后台且焦点在网页里时 `AXFocusedUIElement` 返回 -25212，实时标记完全不工作；树里有 `AXTextArea value=218`。三次尝试 0 条标记。前台未验证 | 取不到时退一步：从焦点窗口的 `AXWebArea` 里找 `AXFocused` 的文本元素。请一个人在前台 Safari 里手测一次，再决定设置页那句话怎么写 |
| S7-03 | P1 | LiveChecker.swift:189 | Safari 地址栏被当成正文：`liveValue` 是页面 URL，并排队送去模型检查（两次）。用户在地址栏打三个词以上的搜索，会被检查、可能被画线 | 跳过工具栏里的 `AXTextField`、搜索框、单行文本框；整段是 URL 的不查 |
| S7-04 | P1 | LiveChecker.swift:408 | ⌘⏎ / ⌃⏎ / ⌥⏎ 被当成采用并吃掉（`where` 只约束最后一个模式，脚本实测）。⇧⏎ 也采用，⇧⇥ 是下一条 | `case kVK_Return where plain, kVK_ANSI_KeypadEnter where plain`；`plain` 把 Shift 算进去；⇧⇥ 做成上一条 |
| S7-05 | P1 | LiveChecker.swift:714；:88 | 拦截不移除，实测两个实例各留下 6 个、3 个；`clear()` 不停拦截，会一直启用 | 整个生命周期只建一个拦截，用启用 / 停用切换；退出时 `CFMachPortInvalidate`；`clear()` 调 `closeCard()` |
| S7-06 | P1 | LiveChecker.swift:389 | ⌃⌘J 跳过光标所在的那条标记；光标后没有标记时回到文首 | 用「标记末尾 ≥ 光标」；没有就取离光标最近的上一条；加 ⌃⌘⇧J 上一条 |
| S7-07 | P1 | LiveChecker.swift:706、:695 | 拦截建不起来或超时时没有任何表现，卡片仍写「⏎ 采用」，⏎ 变成换行 | 建不起来就把卡片文案换成只有按钮，并记日志；超时记一次并提示 |
| S7-08 | P1 | LiveChecker.swift:70、:334 | 键盘滚动、拖动或缩放窗口后，下划线在旧位置停留最多约 2.5 秒；点击判定也用旧坐标 | 监听宿主的 `AXObserver`（移动、缩放、滚动、值变化）来失效缓存，轮询只做兜底 |
| S7-09 | P2 | LiveChecker.swift:394、:411 | ⏎ 和 ⇥ 到末尾都悄悄绕回第一条，⇥ 永远转圈；只剩一条时 ⇥ 等于 Esc | 到末尾停下并提示「还有 N 条跳过的，⌃⌘J 从头看」；卡片上标出绕回 |
| S7-10 | P2 | LiveChecker.swift:376 | 播报：删除、插入、空格类建议念成「to  to .」；没有第几条、采用结果；每条都重复按键说明 | 删除念「删除 X」、插入念「在 X 后加 Y」；带上位置；说明只在第一条说 |
| S7-11 | P2 | LiveChecker.swift:404、:427 | 没有输入法组字判断；写回空档里开始打字后，下一张卡片仍会弹出并抢 ⏎ | 开卡片和处理 ⏎ 之前查 `AXTextInputMarkedRange`；空档里有按键放行过就不再开下一张 |
| S7-12 | P2 | LiveChecker.swift:623、:63 | 卡片是全局浮动层，不跟宿主窗口；别的 App 自己跳到前台后最长 0.5 秒内 ⏎ 仍被吃并改到后台 App | 监听 `didActivateApplicationNotification` 立刻关卡片（SelectionWatcher 已经这么做了） |
| S7-13 | P2 | 面板差异视图 | 长 URL 不换行，超出面板右边被截断 | 允许在 `/` 处断行 |
| S7-14 | P2 | qa/host.sh、测试接口 | 冷启动 Safari 后焦点在地址栏；`quit` 之后 `gbqa.sh` 等不到完成标记，挂满 300 秒 | 测试页加载后由测试接口把焦点放进输入框；`quit` 先写完成标记再退 |

## 测不了的

- Safari 里的一切实时标记行为：速度、准确度、下划线位置、卡片、采用后的文字、其余标记是否跟着移动、`live:z` 的贴合关系。
- 键盘流程的各分支都是读代码，只有「卡片没开时四个键都放行」和「修饰键 ⏎ 的匹配规则」是实测。**S7-01 是读代码推出来的，需要在 TextEdit 里跑一次确认**。
- 真实按键经过拦截的行为：⌘Tab 拦截收不收得到、超时后那次按键的去向、输入法组字。
- VoiceOver 是否真的念出播报。
- Safari 在前台时实时标记是否正常。
- 说明两件我做的事：(1) 我跑了一次 `axprobe:com.apple.Safari`，它会尝试在 Safari 上设两个辅助功能开关再关掉，两次设置都返回了错误码（-25205、-25208），没有生效；(2) Safari 原本没开，是测试把它在后台启动的，现在还开着，里面有我的两个测试标签页（`/tmp/gbtest/host-204448.html`、`host-204653.html`），我没有办法在不弹授权框的前提下关掉它们。

## 我对「⏎ 采用」的判断，以及我会怎么改

**交互上同意**：卡片只在用户主动要的时候开（点一下或 ⌃⌘J），开着时 ⏎ 是「确认眼前这个东西」，和系统的补全、拼写弹窗一致；按别的键就让开，也是对的。⏎ 抢走换行的风险在设计层面已经挡住了。

**工程上现在不合格**，因为「卡片开着」和「⏎ 被拦」不是同一个状态：卡片在写回期间是关的而流程还在继续，拦截在 `clear()` 之后还开着而卡片已经没了。⏎ 的安全性完全取决于这两个状态一致。

我会这样改：

1. 一个明确的状态机：`idle / card(mark) / applying`，拦截只看这个状态。`applying` 时 ⏎ 和 ⇥ 吃掉不处理，其他键放行并结束流程。
2. 拦截只建一次，启用 / 停用；建不起来就退化成「只有按钮」，卡片上不写 ⏎。
3. 采用后不留选区，光标回到用户原来的位置。
4. ⏎ 只认不带任何修饰键、不是 autorepeat、不在组字中的那一次。
5. 序列走到头就停，不绕圈。
6. 如果以上做不稳，退一步用 ⌃⌘⏎ 采用（和 ⌃⌘J 同一组修饰键，手不用动），把裸 ⏎ 留给 App。我更想要裸 ⏎，但前提是 1–4 都做到。
