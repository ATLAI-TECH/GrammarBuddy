# Sam（十年 macOS 开发，全键盘） — 用着顺不顺 Round 8

## 结论（评分 5/10；一句话：Safari 里还是不能开着它写东西，但这次知道原因了，而且是一行能改的）

- **Safari 在前台，实时标记仍然一条都没有**（3 次前台、2 段文字、其中一次是全新实例）。和上一轮不同的是：这次输入框**读到了**（`liveValue` 就是我的 654 个字符，角色 `AXTextArea`，不是地址栏），但**一句话都没有送去检查**。原因在 `LiveChecker.tick()` 的「可见范围」过滤，见 S8-01。这是 P0：我的核心流程走不通。
- 因为没有标记，卡片和按键流程我**一次都没能在 Safari 里跑**。下面关于 `handleKey` 的结论全部是**读代码**，另加三个离线小脚本（引语、`needsDeliberateAccept`、拦截计数）。我没有一条能标「实测通过」的键盘项，这点请按原样理解。
- 读代码看，上一轮的状态机问题改得对：`reviewing / writing` 是明确的状态，修饰键显式判断，长按不连采，拦截只建一个（实测其他三个评审实例各 1 个）。S7-01 的那条路径（新词被换成换行）已经堵住。
- 新发现里最要紧的三条：点开的卡片把 ⌫ 吃掉并永久忽略建议（S8-02）；采用后光标留在被改的词后面、不回到我原来写字的地方（S8-03）；只差大小写的建议全键盘用户根本没法采用，而且 `friday i → Friday I` 被误伤（S8-05）。

## 我试了什么（宿主、文字、每一步和看到的结果，带时间）

宿主：Safari（pid 47932，测试开始时已在运行，里面有我上一轮留下的两个测试标签页）。引擎 `LM Studio / qwen/qwen3-14b` + `gb_live_use_configured=true`。前台用了 **3 次**（上限 8 次），每次 13–23 秒。

测试文字 `/tmp/gbtest/sam-r8-1.txt`（7 句，654 字符）：主谓一致、`wich`、`dont`、`friday i`、`An other`；一句带错的直引号引语；`It's / app's / isn't`；`27" display`（未闭合的英寸号）；行内代码、`macOS 14.5`、`2.4.1`、一个长 URL。
`/tmp/gbtest/sam-r8-2.txt`（3 句短的，103 字符）。

| 时间 | 做了什么 | 结果 |
|---|---|---|
| 21:07 | `qa/host.sh safari sam-r8-1.txt`，后台 `live:app; live:on; wait:3; dump; axtree` | 和上一轮一样：`FOCUSED: none`，`liveValue` 空，0 条。树里有 `AXTextArea value=654` |
| 21:08 | **前台 1**（23 秒）：`live:on` 后 1、2、3 … 20 秒各 `dump` 一次，最后 `live:z`、`axtree` | `FOCUSED: AXTextArea value=654`，父级是 `AXWebArea`（是输入框，不是地址栏）。`liveValue` 正确。但从第一次 `dump` 起状态就是 `Live check: 0 suggestion(s)`，**从来没有出现过「N sentence(s) queued」**，20 秒 0 条。`overlay window #0 follows #0` |
| 21:09 | 后台，面板 `simulate:` 改错同样的两句话 | 12 秒内出结果，4 处改动（见下）。**引擎是好的** |
| 21:10 | 后台再 `axtree` | 这时后台也能读到焦点了（`FOCUSED: AXTextArea`），状态仍是 0 条 |
| 21:11 | 退出实例，重新 `--launch --fresh`（缓存清空），后台每 0.2 秒读一次状态 | 新实例在后台又读不到焦点（`FOCUSED: none`）。后台能不能读到是不稳定的 |
| 21:12 | **前台 2**（22 秒，全新实例）：`live:on` 后 0、0.3、0.6、0.9、1.3、2、4、8、14、20 秒各读一次状态，然后 `live:next` | 10 次全部是 `Live check: 0 suggestion(s)`，没有一次带 queued。`live:next` → `card: none`，提示 `No suggestions here` |
| 21:16 | 换文字：`qa/host.sh safari sam-r8-2.txt`；**前台 3**（13 秒）：同上，加一次 `frontread` | `frontread` → `role=AXTextArea … range=0,0 value=[The tap are installed at login. …]`，文字和光标都读对了。状态仍然始终是 0 条、没有 queued |
| 21:18 | 面板：带长 URL 和 `27" … 13"` 的一段 | 见下 |
| 21:20 | `live:off; quit` | 实例退出了，但 `gbqa.sh` 等了 10 秒还没返回（S7-14 的挂起还在） |

### Safari 前台为什么没有标记（排除法 + 读代码）

读到了什么：元素对（`AXTextArea`，在 `AXWebArea` 里），文字对，光标对（0,0）。

排除掉的：
- **不是引擎**：同一个实例、同一份配置，面板 12 秒内改完同样的句子。
- **不是缓存**：前台 2 是全新实例，`cache` 是空的。
- **不是 `worthChecking` 和分句**：我把 `paragraphs(of:)`、`worthChecking`、`Tokenizer` 原样拷到仓库外编译跑了一遍，7 句全部 `worth=true`。
- **不是「还没轮到」**：`tick()` 只要有一句待查，状态就会是「…, N sentence(s) queued」（LiveChecker.swift:182）。我在 `live:on` 后 0 秒到 20 秒采了 10 次，一次都没有。14b 的模型不可能在 0.3 秒内查完 7 句。

剩下的只有一个条件（LiveChecker.swift:173–177）：

```swift
let visible = (isWord ? nil : visibleRange(el)) ?? NSRange(location: 0, length: ns.length)
…
let pending = todo.filter { NSIntersectionRange($0.range, visible).length > 0 && cache[$0.text] == nil && worthChecking($0.text) }
```

`visibleRange(el)` 读 `AXVisibleCharacterRange`。Safari 的 `<textarea>` **有**这个属性（`axtree` 里看得到），所以不会走 `?? 全文` 的兜底；但它给的范围和任何一句都不相交（最可能是 `{0,0}`，WebKit 对文本控件的这个属性一向不可靠），于是 `pending` 永远是空的，状态直接落到 `Live check: 0 suggestion(s)`。

**我没能直接读到这个属性的值**：我的终端没有辅助功能权限（`AXIsProcessTrusted() == false`），测试接口里也没有能打印它的命令。所以上面是排除法得出的结论，不是直接测量。请在 `dump` 里加一个 `liveVisibleRange` 字段确认一下，一分钟的事。

**改法**（都在 `tick()` 里）：

```swift
var visible = NSRange(location: 0, length: ns.length)
if !isWord, let v = visibleRange(el), v.length > 0, NSMaxRange(v) <= ns.length { visible = v }
```

也就是：空的、越界的可见范围一律当作「不知道」，查全文。更稳的做法是对 `AXWebArea` 里的元素完全不信这个属性，「在不在屏幕上」交给 `rebuildMarks` 里已有的 `frame.contains(rect 中心)`。另外状态文字应该区分「查完了，0 处」和「有 7 句但都不在可见范围里」，否则这种问题从外面看和「你的文字没毛病」一模一样。

**即使改了，Safari 里的采用也没验证过**（S8-06）：Safari 不在 `AppProfiles.clipboardReaders` 里，所以采用只走 `AXSelectedText` 写入这一条路，没有粘贴兜底。WebKit 的元素上挂的是 `AXReplaceRangeWithText`（`axtree` 里每个元素都有），`AXSelectedText` 写不写得进去我不知道。

### 位置是否合理（`AXBoundsForRange` 还是 text marker）

没有标记，测不了。能说的：`AXTextArea` 的参数化属性里 `AXBoundsForRange`、`AXTextMarkerForIndex` 系列、`AXBoundsForTextMarkerRange` 都在；`TextGeometry.bounds` 先试 `AXBoundsForRange`，返回 0×0 才走 text marker。Safari 里实际走哪一条、矩形准不准，要等 S8-01 改了才能看。

## 七个问题的回答

1. **等多久**：Safari 里等不到。前台 20 秒 0 条，而且不是慢，是根本没开始查。
2. **标得对不对**：实时标记没有产出。面板里同一个模型的结果见下一节。
3. **键盘流程**：没法跑。读代码的结论见「handleKey 状态机走查」。⏎ 这个设计我仍然同意，状态机这次写对了大半；我现在的顾虑转到了 ⌫ 和「点开的卡片」上（S8-02）。
4. **采用之后**：没法跑。读代码：新词后面留光标、不留选区（对）；但光标不回到我原来的位置（S8-03）。
5. **段落改写**（面板，实测）：见下一节。引语里的改动默认不采用、带橙色引号角标和一行说明，这个做得好。
6. **翻译并润色**：这一轮没有重测，上一轮的结论不变。
7. **整体**：面板可以用。实时标记在我的宿主里两轮都没见到。会让我关掉它的：S8-01（没有）、S8-03（改完三个词之后我的光标不在原地）。

## 模型的建议逐条评（原词 → 新词：对 / 错 / 没必要）

实时标记没有产出，下面是面板「改错」（同一个模型）：

| 改动 | 评价 |
|---|---|
| `were → was`（he were right） | 对 |
| `friday i → Friday I` | 对，而且合并成了一条。但合并之后在实时标记里会被判成「只能点击采用」，见 S8-05 |
| `work → worked` | 对 |
| 引语里的 `dont returns`（删 s） | 被拦住、默认不采用，对。模型没改 `dont` |
| `api → API` | 对。实时标记里同样只能点击采用 |
| `the the → the` | 对 |
| 漏：`The API token … are stored` | 应为 `is stored`，没改 |
| 漏：`a 27" display and a 13" display is both` | 应为 `are both`，没改 |

代码、`2.4.1`、`macOS 14.5`、URL 都没动。长 URL 在面板里仍然超出右边被截断（`/tmp/gbqa/sam/r8-url-0.png`，S7-13 没改）。

## handleKey 状态机走查（读 LiveChecker.swift:482–527、:530–586；全部未运行）

| 场景 | 现在会怎样 | 判断 |
|---|---|---|
| 写回期间按 ⏎ / ⇥ / ⌫ / Esc | `reviewing` 仍为真，`writing` 为真 → 吃掉，不处理（:503） | 对。S7-01 的路径堵住了 |
| 写回期间按 Esc | 也被吃掉且**不生效**，下一张卡片照样弹出，要再按一次 | 小毛病：Esc 应该记下来，写完就结束 |
| 写回期间按普通键 | `closeCard()`，键进 App；写完后 `finish` 看到 `reviewing == false` 不再开下一张 | 对（上一轮 S7-11 的后半条顺带好了） |
| 带修饰键（⌘⏎ ⌃⏎ ⌥⏎ ⇧⏎ ⇧⇥） | `plain` 现在含 Shift，非 plain 一律 `closeCard()` 并放行（:491、:500） | 对。没有做「⇧⇥ = 上一条」 |
| 长按 | autorepeat 在评审中一律吃掉（:503）；评审结束后 0.8 秒内的重复 ⏎ 也吃（:497） | 基本对。按住超过约 0.8 秒后，重复的 ⏎ 会开始进 App（S8-13） |
| 最后一条之后的宽限期 | `finishReview()`：`swallowUntil = now + 0.8`，拦截多留 0.9 秒 | 对。但只有 `finishReview` 这一条路有宽限，别的结束方式没有（S8-04） |
| 宽限期里我真想按的 ⏎ | 被吃掉，没有任何表示（提示条只说「都处理完了」） | 可以接受；0.8 秒偏长，建议 0.4 秒，或者只吃 autorepeat 和 250 ms 内的第二下 |
| 别的 App 到前台 | `didActivateApplicationNotification` → `closeCard()`（:77–83） | 代码是对的。QA 钉住宿主时这个分支被 `qaTargetPID == nil` 关掉，所以测试接口测不到 |
| 焦点离开文本框 | `clear()` 现在调 `closeCard()`（:111） | 对 |
| 拦截的数量 | `KeyTap` 只建一次，之后启用 / 停用 | **实测**（`CGGetEventTapList`）：wang（pid 83273）、priya（83349）、另一个实例（83770）各 **1 个** keyDown 拦截，空闲时 `enabled=false`。上一轮是 6 个和 3 个。我自己的实例没开过卡片，0 个 |
| 拦截建不起来 | `keysWork = false`，卡片写「按键现在不可用，请用鼠标点」 | 对。但建过之后 `start()` 永远返回 true，不查 `CGEvent.tapIsEnabled`：运行中被撤销权限时卡片仍写「⏎ 采用」 |

### 我认为还有漏洞的地方

1. **评审非正常结束时没有宽限（S8-04）**。`accept` 的 `finish` 里先调 `self.tick()`（:548）。这一次 `tick()` 只要读不到焦点元素（辅助功能调用超时是 0.3 秒；Safari 的焦点报告本来就时有时无，我这一轮亲眼看到它在「有」和「none」之间变了两次），就走 `clear()` → `closeCard()`，`reviewing` 变假；回到 `finish`，`advance && self.reviewing` 为假，评审静悄悄结束，**没有设 `swallowUntil`**。我正按着 ⏎ ⏎ ⏎ 的节奏，下一下就进了 App：光标在刚采用的词后面，于是句子中间多一个换行。比上一轮的「词被换成换行」轻，但还是改了我的文字。
2. **`open()` 和 `closeCard()` 都把 `writing` 置回 false（:429、:443）**，而写回的任务还在跑。写回期间点另一条下划线（或按带修饰键的键后马上 ⌃⌘J）会开出新卡片，这时 ⏎ 会发起第二次并发写入。替换类的有 `axString == removed` 把关，只会失败并被记进 `ignored`；**纯插入没有任何校验**（WriteBack.swift:35 `range.length == 0 ||`），会按过期的位置插进去。窗口很窄（几十到几百毫秒，Word 是 250 ms 以上），但后果是插错位置（S8-12）。
3. **`writing` 没有超时（S8-11）**。Word 走 `WordBridge.run`，这个函数没有超时（`runScript` 有，它没有）。Word 弹了模态框时脚本会一直挂着：卡片已经收起，屏幕上什么都没有，而 ⏎ ⇥ ⌫ Esc 在所有 App 里都被吃掉，直到我按一个别的键。
4. **拦截回调里做的事太多（S8-15）**。`handleKey` 在拦截回调里同步执行：`ignore()` 会 `rebuildMarks`（每条标记一次辅助功能调用，单次最长 0.3 秒），`open()` 会建 SwiftUI 窗口并发播报。回调慢了系统会停用拦截并把这次按键放行，于是 ⌫ 既忽略了建议，又在文字里删了一个字。应该先决定吃不吃、立刻返回，其余的 `DispatchQueue.main.async`。

## 新问题的专项检查

**⌫ 作为忽略键（S8-02）**。卡片有两种打开方式：⌃⌘J，或者**点一下有下划线的词**。第二种和「把光标点进这个词里自己改」是同一个动作。这时：
- 按字母键：卡片关，字母进 App。对。
- 按 ⌫：被吃掉，字没删；这条建议进了 `ignored`，下划线消失，**没有提示，没有撤销**（`ignored` 整个会话都不清）。
- 按 ⇥（⇥ 采用模式下是 →）：被吃掉，卡片跳到别处的下一条。

上一轮 ⌫ 是「关卡片并照常删字」。现在对一个想手动改这个词的人，第一下 ⌫ 无效并且丢掉了建议。我的建议：⌫ / ⇥ / → 只在 ⌃⌘J 开始的评审里接管；点开的卡片只接 ⏎ 和 Esc。忽略之后给一条「已忽略 · ⌃⌘Z 撤销」之类的提示。

**`needsDeliberateAccept`（S8-05）**。把这个函数原样拷出来跑：

| 建议 | 结果 |
|---|---|
| `friday → Friday`、`i → I`、`the → The`、`dont → don't`、`3 → three` | 可以按键采用（对） |
| `FLC → flc`、`Col-0 → col-0`、`h2o → H2O`、`ipv6 → IPv6` | 只能点击（符合设计） |
| **`friday i → Friday I`** | **只能点击**。`WordDiff.merge` 把相邻的两处合成了一条（面板里也是这样显示的），合并后首字母以外也有大小写差异。`On friday i tested…` 是最常见的错，被误伤 |
| `api → API`、`ok → OK`、`iphone → iPhone`、`Github → GitHub`、`macos → macOS` | 只能点击。这些都是改对，而且是工程师文字里最多的一类 |
| `2nd → second`、`1st → first`、`10am → 10 am` | 只能点击（被「字母 + 数字」规则带上） |

更大的问题：**被判成「只能点击」的建议，全键盘用户没有任何办法采用**。⏎ 只是让卡片抖一下，带修饰键的 ⏎ 会关卡片。我的建议：(a) 第二次 ⏎（1.5 秒内）算确认，卡片写「再按一次 ⏎ 确认」；(b) 规则收窄到「原词全大写变小写 / 含数字且看起来像记号」，按词逐个判断而不是对合并后的整串判断；`小写 → 首字母大写或全大写` 放行。

**`Quotes.ranges`（S8-09）**，原样拷出来跑：

| 输入 | 结果 | 判断 |
|---|---|---|
| `It's the app's job, isn't it.` | 无 | 对，撇号不受影响 |
| `Drawn too low on a 27" display, wich are bad.` | 无 | 对，未闭合的直引号到行尾作废 |
| `A 27" display and a 13" display are … the the overlay.` | `" display and a 13"` 被当成引语 | 两个英寸号之间的正文不再标。小范围误伤。数字后面紧跟的 `"` 不该当开引号 |
| `She said "this are fine and nobody close…`（没闭合） | 无 | 引语在打完右引号之前会被标，闭合后标记消失 |
| `He wrote “this are wrong and never closed…` | 无 | 同上 |
| `‘the callback dont return’ he said` | 无 | 英式单引号的引语不保护 |
| `„Das sind falsch“ …, und “this are wrong” too.` | 两段都识别 | 对 |
| `` The `"key"` field … `` | `"key"`、`"value"` | 无害 |
| **跨句的引语**：`The reviewer wrote "this callback are slow. It dont return in time." Then…` | 分句后每句只有一个引号，**两句都没有引语范围** | 漏洞：`rebuildMarks` 是对每一句单独调 `Quotes.ranges(in: p.text)`（:334），引语只要超过一句就完全不受保护。弯引号 `“… . …”` 同样。应该在整段文字上算一次引语范围，再换算到各句 |

**`skipped` / `ignored` 在文字变化后（S8-08）**。
- 标记的 `id` 是「句子原文 + 句内位置」（:347）。同一句里采用了别的建议之后句子原文变了，同句其余标记的 `id` 全变，`skipped` 里的旧 `id` 对不上。实际影响小：`nextMark` 只往后走，`finishReview` 会清空 `skipped`；只有 Esc 之后打了字再 ⌃⌘J 时，跳过的那条会再出现一次。
- 反过来的问题更实在：`id` 和 `ignored` 的键（`句子|原词|新词`，:335、:613）都**不含绝对位置**。同一句里有两处 `are → is`，按 ⌫ 忽略一处，两处下划线一起消失；文档里有两行一样的句子，跳过或忽略一处等于处理了两处。
- **采用失败也写进 `ignored`**（:543）。提示说「切到它再试」，但下划线已经没了，试不了（S8-07）。

**⇥ 采用模式（`gb_live_accept_key=tab`）**（读代码，未运行）。按键逻辑本身自洽：⇥ 采用，→ 跳过（方向键带的 Fn / 小键盘标志不在 `plain` 的判断里，没问题），⏎ 走默认分支关卡片并进 App，宽限期吃的是 ⇥。不自洽的是文案（S8-10）：
- `open()` 的播报写死了「回车采用，Tab 跳过」（:436），⇥ 模式下是错的，而且照着按 ⏎ 会在文字里插入换行。
- 「只差大小写」那行提示写死了「⇥ 跳过」（:826），⇥ 模式下 ⇥ 是采用键（会抖一下），跳过是 →。
- 两种模式都没有「上一条」。→ 是跳过，← 却是关卡片并移动光标，不对称。

**⌃⌘J 从哪里继续**。`reviewNext` 在文字没变时从上一张卡片之后继续（:459）。如果我关了卡片、把光标点到别的段落再按 ⌃⌘J，它仍然回到上一张卡片后面，不是光标这里。应该是「文字没变并且光标也没动」才续（S8-14）。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| S8-01 | P0（实测） | LiveChecker.swift:173–177、:230 | Safari 在前台、焦点在 `<textarea>`：文字读到了，但一句都不送检，状态一直是 `0 suggestion(s)`，从不出现 queued。3 次前台、2 段文字、全新实例都一样。排除法指向 `AXVisibleCharacterRange` 返回了不与任何句子相交的范围 | 空的或越界的可见范围当作未知，查全文；`AXWebArea` 里不用这个属性。`dump` 里加 `liveVisibleRange`。状态区分「查完 0 处」和「没有可查的句子」。设置页「Safari 按同样的办法工作」这句先拿掉 |
| S8-02 | P1（读代码） | LiveChecker.swift:400–407、:501–506、:611 | 点一下有下划线的词（想把光标放进去手动改）→ 卡片开 → 按 ⌫：字没删，建议被永久忽略，无提示无撤销。⇥ / → 同样被吃并跳走 | ⌫ / ⇥ / → 只在 ⌃⌘J 开始的评审里接管；点开的卡片只接 ⏎ 和 Esc。忽略后给可撤销的提示 |
| S8-03 | P1（读代码） | LiveChecker.swift:582 | 采用后光标放在新词后面，评审结束也不回到用户原来的位置。在段尾写着字，⌃⌘J ⏎ ⏎ ⏎ 改了上面三处，接着打字：字出现在最后改的那个词后面 | `open()` 第一张卡片时记下光标（文字变了就按每次采用的长度差平移），评审结束（任何方式）时还原 |
| S8-04 | P1（读代码） | LiveChecker.swift:548–549、:108–114 | `finish` 里的 `tick()` 一旦读不到焦点元素就 `clear()`，评审无声结束且没有宽限；节奏里的下一下 ⏎ 进 App，在刚采用的词后面插入换行 | 所有「不是用户按键导致」的结束（`clear()`、换元素、别的 App 激活、`finish` 的 else 分支）都设 `swallowUntil`；`finish` 里单次读失败先重试一次再放弃 |
| S8-05 | P1（脚本实测判断函数） | LiveChecker.swift:34–39、:508 | 只能点击的建议没有任何键盘采用方式；`friday i → Friday I`（合并后）、`api → API`、`ok → OK`、`Github → GitHub`、`2nd → second` 都被判成只能点击 | 第二次 ⏎ 确认；规则按词判断，`小写 → 大写` 方向放行，只拦 `大写 → 小写` 和像记号的词 |
| S8-06 | P1（未验证） | LiveChecker.swift:560–585；AppProfiles | Safari 的采用只走 `AXSelectedText` 写入，没有粘贴兜底；WebKit 暴露的是 `AXReplaceRangeWithText`。S8-01 改好后很可能是下一个拦路的 | 前台 Safari 里手测一次采用；不行就加 `AXReplaceRangeWithText` 或和 Chrome 一样走「选中 + 粘贴」 |
| S8-07 | P2 | LiveChecker.swift:543 | 采用失败把建议写进 `ignored`，提示却说「切到它再试」，下划线已经消失 | 失败只在本轮评审里跳过（放进 `skipped`），不要永久忽略 |
| S8-08 | P2 | LiveChecker.swift:335、:347、:613 | `ignored` 的键和标记 `id` 不含位置：同句两处相同的改动忽略一处两处都没；相同的句子互相影响 | 键里加句内位置（`id` 已有）和段落序号 |
| S8-09 | P2（脚本实测） | Quotes.swift；LiveChecker.swift:334 | 跨句的引语完全不受保护（按句算引语）；`27" … 13"` 之间的正文被当引语；英式单引号 `‘ ’` 不识别；引语打到一半时先标、闭合后消失 | 在整段上算引语范围；数字后的 `"` 不作开引号；加 `‘ ’`（注意排除撇号）；未闭合的引号到段尾都当引语 |
| S8-10 | P2 | LiveChecker.swift:436、:826 | ⇥ 采用模式下播报仍说「回车采用，Tab 跳过」，「只差大小写」提示仍写「⇥ 跳过」 | 按 `acceptWithTab` 生成这两处文案 |
| S8-11 | P2 | LiveChecker.swift:553–558；WordBridge.swift:18 | `writing` 没有超时。Word 脚本挂住时卡片已收起，⏎ ⇥ ⌫ Esc 全系统被吃；写回期间的 Esc 被吃且不生效 | `writing` 超过 1.5 秒就结束评审并提示；`liveReplace` 用带超时的执行；写回期间卡片不要消失，改成「正在写入」；Esc 记下来写完即结束 |
| S8-12 | P2 | LiveChecker.swift:429、:443；WriteBack.swift:35 | `open()` / `closeCard()` 把进行中的 `writing` 清掉，可以并发写；纯插入不校验位置 | `writing` 只由写回任务自己清；插入也校验前后各一个词 |
| S8-13 | P2 | LiveChecker.swift:497、:523 | 最后一条之后按住 ⏎ 超过约 0.8 秒，重复的 ⏎ 开始进 App；宽限期吃掉真想按的 ⏎ 没有表示；鼠标点「采用」结束的评审也有宽限 | 宽限期内一旦收到 autorepeat 就一直吃到下一次非重复的按下；真按键的宽限缩到 0.4 秒 |
| S8-14 | P2 | LiveChecker.swift:459、:526 | 关卡片后把光标移到别处再 ⌃⌘J，仍从上一张卡片后继续；从中间点开或有跳过的条目时，结束提示仍说「都处理完了」；没有「上一条」 | 光标动过就按光标找；提示写「到末尾了，还有 N 条」；加 ⌃⌘⇧J |
| S8-15 | P2 | LiveChecker.swift:867、:611–615、:426–437 | 拦截回调里同步做辅助功能调用和建窗口，慢了会被系统停用并放行这次按键 | 回调里只做判断，其余异步 |
| S8-16 | P2 | LiveChecker.swift:77、:853；SettingsView.swift:37 | 每次 `start()` 多加一个 `didActivate` 观察者，`stop()` 不移除；`KeyTap.start()` 不查 `tapIsEnabled`；设置页仍写 Safari「按同样的办法工作」 | 保存并移除观察者；启用后查一次；改文案 |
| S8-17 | P2 | LiveChecker.swift:150 | Safari 在后台时焦点时有时无（到过前台后的一段时间里能读到，新启动的实例又读不到）；读不到时状态是空字符串，用户看不出原因 | 取不到时从焦点窗口的 `AXWebArea` 里找 `AXFocused` 的文本元素（上一轮 S7-02 的建议） |

## 上一轮问题的复查（第 8 轮才写）

说明：因为 Safari 里没有标记，卡片开不出来，下面除了注明「实测」的，都是**读代码确认**，没有运行过。按说明「✅ 要实际试过才算」，所以我只给两条打 ✅。

| ID | 处理说明里的状态 | 我的结论 | 依据 |
|---|---|---|---|
| S7-01 | ✅ | 代码已改，没法实测 | `reviewing / writing` 状态、写回期间吃键、`setRange(resume, 0)`、0.8 秒宽限都在。残留：S8-03、S8-04 |
| S7-02 | ◐ 第 8 轮前台验证 | **没改好**（实测） | 前台能读到输入框了，但仍然 0 条标记，新原因 S8-01。后台仍然时有时无 |
| S7-03 | ✅ | 代码已改，没法实测 | 工具栏里的文本框、搜索框被跳过，`file:` / 网址 / 邮箱整行不查。这一轮焦点没落到过地址栏，没触发 |
| S7-04 | ✅ | 代码已改，没法实测 | `plain` 显式判断并包含 Shift，非 plain 一律关卡片放行。⇧⇥「上一条」没做 |
| S7-05 | ✅ | **改好了 ✅**（实测） | `CGGetEventTapList`：三个开过卡片的评审实例各 1 个拦截，空闲时停用。`clear()` 调 `closeCard()` 是读代码 |
| S7-06 | ✅ | 代码已改，没法实测 | 「标记末尾 ≥ 光标」；没有就取最近的。没有「上一条」；续接不看光标（S8-14） |
| S7-07 | ✅ | 部分 | 建不起来时卡片文案换了。超时仍不记录、不提示；不查 `tapIsEnabled` |
| S7-08 | ◐ | 部分（和说明一致） | 缓存 1 秒，滚轮清缓存。键盘滚动、拖动窗口后仍滞后约 1–1.5 秒 |
| S7-09 | ✅ | 代码已改，没法实测 | 不再绕回，到末尾 `finishReview()`。提示文字在有跳过条目时不准（S8-14） |
| S7-10 | ✅ | 代码已改，没法实测 | 播报带第几条、插入 / 删除有专门说法。按键说明只在「全文第 1 条」念，不是「本次评审的第一张卡片」；⇥ 模式下念错（S8-10） |
| S7-11 | ⏸ | 没改 | 说明里写「别的 App 里拿不到组字状态」，对 Safari 不成立：这一轮 `axtree` 里焦点所在的 `AXTextArea` 明明有 `AXTextInputMarkedRange` |
| S7-12 | ✅ | 代码已改，没法实测 | `didActivateApplicationNotification` → `closeCard()`。QA 钉住宿主时这个分支不走，测试接口测不到。卡片仍是 `popUpMenu` 层级、所有桌面可见 |
| S7-13 | ⏸ | **没改**（实测） | 长 URL 仍然超出面板右边被截断，`/tmp/gbqa/sam/r8-url-0.png` |
| S7-14 | ⏸ | **没改**（实测） | `quit` 之后 `gbqa.sh` 10 秒没返回；冷启动焦点这一轮没碰到 |

合计：代码已改 8 条（S7-01、03、04、05、06、09、10、12；其中实测确认 1 条），部分 2 条（S7-07、08），没改好 4 条（S7-02、11、13、14）。

## 测不了的

- Safari 里实时标记的一切：速度、准确度、下划线位置和走哪条几何路径、`live:z` 的贴合、卡片、采用后的文字。
- `handleKey` 的所有分支都没有运行过，包括说明里要求重点试的五项（连按两次 ⏎、最后一条后的 ⏎、连续 ⇥、⌫、⇥ 采用模式）。测试接口的 `live:key=` 本身也测不了带修饰键和 autorepeat 的情况（它固定传 `modifiers: []`、`isRepeat: false`）。
- `AXVisibleCharacterRange` 的实际返回值（我的终端没有辅助功能权限，测试接口没有对应命令）。S8-01 的原因是排除法。
- Safari 里 `AXSelectedText` 写入是否生效（S8-06）。
- 真实按键经过拦截的行为、VoiceOver 是否念播报、别的 App 激活时是否立刻关卡片。
- 说明几件事：
  - 我没有用 TextEdit 去跑键盘流程，因为那不是分配给我的宿主。如果允许，S8-02、S8-04、S8-13 在 TextEdit 里十分钟就能确认。
  - Safari 里现在有我这一轮新开的两个测试标签页（`/tmp/gbtest/host-210747.html`、`host-211649.html`）和上一轮的两个，我没有办法在不切前台、不弹授权框的前提下关掉它们。
  - 21:10 左右有一次看到前台 App 是 `com.apple.UserNotificationCenter`（系统弹了某个对话框）。我不知道是谁触发的；我跑过一个没有辅助功能权限的只读脚本（调用直接返回 -25211，按理不会弹框）。
  - 我在仓库外（`/tmp/gbqa/sam/scripts/kt`）编译了 `Quotes.swift`、`WordDiff.swift` 的副本和拷出来的 `paragraphs / worthChecking / needsDeliberateAccept` 来跑边界用例，没有改仓库。

## 我对「⏎ 采用」的判断（更新）

仍然同意，而且这一轮的状态机让我比上一轮放心：⏎ 的归属现在只看 `reviewing`，不再看卡片在不在屏幕上。还差三件事才算做稳：评审的**每一种**结束方式都要有宽限（S8-04）；`writing` 要有超时并且只由写回任务自己清（S8-11、S8-12）；光标要还给我（S8-03）。⌫ 和 ⇥ 的接管范围则应该收窄到键盘发起的评审（S8-02）。
