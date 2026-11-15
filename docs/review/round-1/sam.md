# Sam（macOS 工程师，VoiceOver + 全键盘用户）— 设计评审 Round 1

评的是 `DESIGN.md` v1（2026-11-14，评审前）和 `INVESTIGATION.md`（2026-11-14）。

## 结论（评分 5/10；一句话：按这份设计做出来，我会不会用，为什么）

**现在这份设计做出来我用不了，但方向是对的，改几处就能用。** 「不做实时下划线、只做选中 + 快捷键 + 面板」这个范围选得很准，Carbon 热键、分层兜底、写前复查这些骨架也都成立。但设计稿最核心的一句话——「面板不抢焦点」同时「按 ⏎ / Tab / 数字键 / Esc 操作面板」——没有说键盘事件怎么到面板，这两件事按字面是互相矛盾的；全稿没有一个字提无障碍，默认快捷键 ⌃⌥G / ⌃⌥T 还正好压在 VoiceOver 的修饰键上；Word 分片替换按「字符位置」写回，在脚注、批注、已有修订的文档里有写错地方的风险。这三件事不解决，我（以及任何开着 VoiceOver 或在脚注里改稿的人）会在第一天放弃。

## 我只读核对了什么（结果）

环境：本机 macOS 26.6.1（`sw_vers`），SDK `MacOSX.sdk` 的 `SDKSettings.json` 显示为 macOS 27.0，Word 16.114.4。没有启动任何 App，没有跑 osascript。

| 核对项 | 查的文件 | 结果 |
|---|---|---|
| `kAXSelectedTextAttribute` / `kAXSelectedTextRangeAttribute` / `kAXBoundsForRangeParameterizedAttribute` | `HIServices/AXAttributeConstants.h` 694、709、1312 行 | 三个常量都存在。**但头文件对 `kAXSelectedTextAttribute` 的说明写的是「Writable? No.」**（684–692 行），`kAXSelectedTextRangeAttribute` 才是「Writable? Yes」。设计稿 §4.2 的主写入路径依赖的是文档写明不可写的属性（实际上 NSTextView 等确实接受写入，但这是「各 App 自己的实现」，不是契约）。 |
| `AXSecureTextField` | `HIServices/AXRoleConstants.h` 408 行 | 只有 `kAXSecureTextFieldSubrole`。它是 **subrole**，不是 role。§4.1 的写法「焦点元素是密码框（AXSecureTextField）」实现时要查 `AXSubrole`，查 `AXRole` 永远不命中。 |
| `AXUIElementIsAttributeSettable`、`AXIsProcessTrustedWithOptions`、`AXUIElementSetMessagingTimeout` | `HIServices/AXUIElement.h` 204、64、402 行 | 都存在。 |
| 网页选区用的 text marker 接口 | `HIServices/AXWebConstants.h` 272、488、527 行 | `kAXSelectedTextMarkerRangeAttribute`、`kAXStringForTextMarkerRangeParameterizedAttribute`、`kAXBoundsForTextMarkerRangeParameterizedAttribute` 存在。设计稿没提这一套。 |
| `AXManualAccessibility` / `AXEnhancedUserInterface` | 在 HIServices 全部头文件里 grep | **没有命中**。这两个是 Chromium / Electron 约定的非公开属性名，SDK 里没有常量。 |
| `RegisterEventHotKey` | `HIToolbox/CarbonEvents.h` 15428–15484 行 | 存在，标注 10.0 起可用，我看到的声明处没有弃用标记。「不需要辅助功能权限」这点头文件不会写，我没实测；作者自己的记忆库里有别的项目这么用过的记录。 |
| `CGPreflightPostEventAccess` / `CGRequestPostEventAccess` | `CoreGraphics/CGEvent.h` 405、408 行 | 存在（10.15+）。模拟 ⌘C / ⌘V 能不能发，可以用它预检。 |
| `NSWindowStyleMaskNonactivatingPanel`、`becomesKeyOnlyIfNeeded`、`canBecomeKeyWindow`、`NSWindowCollectionBehaviorFullScreenAuxiliary` / `CanJoinAllSpaces` | `AppKit/NSWindow.h` 51、66、438、101、118 行；`NSPanel.h` 16 行 | 都存在。头文件对 non-activating 的说明只有「不激活所属 App」，**没有说它收不收键盘**；收不收取决于面板是否成为 key window，这正是设计稿没写的地方。 |
| `NSAccessibilityAnnouncementRequestedNotification`、`NSAccessibilityPriorityKey` | `AppKit/NSAccessibilityConstants.h` 494、608 行 | 存在，可以用来播报「完成，2 处修改」。 |
| `AEDeterminePermissionToAutomateTarget` | `AE/AppleEvents.h` 363 行 | 存在，可以预检 Word 的自动化授权状态。 |
| `TranslationSession.init(installedSource:target:)` | `Translation.swiftmodule/arm64e-apple-macos.swiftinterface` 187–188 行 | 标注 macOS 26.0，和设计稿 §6.5 一致。 |
| `prepareTranslation()`、`Configuration.invalidate()`、`LanguageAvailability.status(...)` | 同上 184、173、33–34 行 | 存在；类本身 macOS 15.0 起。 |
| `.translationTask` | `_Translation_SwiftUI.swiftmodule` 26、28 行 | 存在，标注 macOS 15 起（行被我截断，只看到 `macOS 15.` 开头）。 |
| `FoundationModels.framework`、`NLLanguageRecognizer` | SDK 目录、`NaturalLanguage/NLLanguageRecognizer.h` | 存在。 |
| Word：`track revisions` | `Word.sdef` 3817 行 | 文档属性，可读写。和 §4.3 一致。 |
| Word：按字符位置取范围 | `Word.sdef` 2238–2243 行 | `create range`，直接参数是 **document**，`start` / `end` 是整数字符位置，返回 `text range`。另有 `set range`（8933 行，作用在 text range 上）。所以「按字符范围替换」在字典层面有对应命令。 |
| Word：范围内容可写 | `Word.sdef` 9156 行 | `text range` 的 `content` 属性没有 `access="r"`，可写。 |
| Word：选区位置 | `Word.sdef` 4486、4489 行 | `selection start` / `selection end` 存在；9159、9188 行 `end of content` / `start of content` 只读。 |
| Word：选区所在的 story | `Word.sdef` 4496 行、5455–5469 行 | 选区有只读的 `story type`，枚举里有正文、脚注、尾注、批注、文本框、页眉页脚等。选区还有 `text object`（返回 text range）和 `story length`。 |
| Word：修订显示方式 | `Word.sdef` 4598–4639 行 | 有 `text retrieval mode`（含 `include hidden text`）、`revisions view`（final / original）、`show revisions and comments`。说明「取到的文字里包不包含已删除的修订文字」是受视图状态影响的。 |
| Word：撤销分组 | 在 `Word.sdef` 里 grep `undo record` / `custom record` | **没有命中**。只有 `undo`（可带次数）、`redo`、`undo clear`。AppleScript 这边没有把多步操作合成一步撤销的接口。 |
| Word：是否声明了系统服务 | `plutil -extract NSServices` 读 Word 的 `Info.plist` | 没有这个键（Word 自己不提供服务；它是否作为「请求方」支持服务菜单，我没验证）。 |

以下判断我**没有验证**（没有可运行的 App、也不允许控制其他 App），报告里用到的地方都会再标一次：Chromium / Electron 默认不暴露辅助功能树；non-activating 面板成为 key 时各类 App 的选区是否保留；VoiceOver 对 ⌃⌥G / ⌃⌥T 的具体绑定；Word 的字符位置和 Swift 字符串下标的换算；通过辅助功能接口写入后能否 ⌘Z。

## 我的任务和走查过程

机器：MacBook Pro M4 Max 64 GB，macOS 26，VoiceOver 常开，「键盘导航」打开，Ollama 已装。

### 任务 1：首次安装到第一次改错（VoiceOver 开着）

1. 下载 DMG，拖进应用程序，打开。§3.1 说 Developer ID 签名加公证，Gatekeeper 这步没问题。
2. 引导第 1 步「试一下」：窗口里有示例文字，让我选中后按 ⌃⌥G。**卡住**：⌃⌥ 是 VoiceOver 的修饰键（VO 键），⌃⌥ 加字母整个空间都是 VoiceOver 命令。我按下 ⌃⌥G，要么被 VoiceOver 吃掉，要么 VoiceOver 和 GrammarBuddy 同时响应（哪一种我没验证）。⌃⌥T 同理，我记忆里它是 VoiceOver 的「朗读文字属性」。设计稿 §2.1 写了「可改」，但引导第 1 步在我能改之前就要求我按它。
3. 假设我先去设置里改成 ⌃⇧G。回到引导按下，设计稿说面板出现并自动开始改错。**设计稿没说**：这时 VoiceOver 光标去哪？§2.2 说面板「不抢焦点」。如果面板不是 key window，VoiceOver 不会跟过去，我听不到任何东西——没有播报「面板已打开」，流式结果也不会念。我得用 VoiceOver 的窗口选择器去找一个别的 App 的浮动面板，而且它没有标题。
4. 就算 VoiceOver 进了面板：§2.1 第 3 步说「删掉的红色删除线，新增的绿色」。**只有颜色和删除线，没有任何文字化的表述**。VoiceOver 会把 `Their There are three reasons why this approach work works better` 连着念出来，我分不清哪个是删的哪个是加的。「2 处修改」是一个计数，没有可以逐条浏览的列表。
5. 引导第 2 步辅助功能权限：有「打开系统设置」按钮，可以。**没说**授权后 App 怎么知道（轮询 `AXIsProcessTrusted`？要不要重启？），引导会不会自动进到下一步。
6. 第 3 步探测到 Ollama 的 11434 端口，列出模型。可以。

结论：第一次成功用上，对我来说在第 2 步就断了；改完快捷键以后在第 3–4 步是「能触发但听不到结果」。

### 任务 2：在 Xcode / TextEdit（原生 AppKit）里改一段提交说明

选中 `Fix crash when the user have no selection and press hotkey`，按快捷键。

1. §3.3：记下前台 App → 读选区。原生 NSTextView，`AXSelectedText`、`AXSelectedTextRange`、`AXBoundsForRange` 都拿得到，这条路径我相信。
2. 面板出现在选区下方，开始流式显示。
3. 我按 **⏎**。**这是全稿最大的洞**。按 §2.2 字面理解，面板 non-activating、原 App 在前台、「这样替换时选区还在」。那 ⏎ 这个按键事件发给谁？
   - 如果面板**不是** key window：⏎ 进了 Xcode，把我选中的文字**替换成一个换行**。原文没了，面板里的结果也和选区对不上了（§4.2 的写前检查会发现「选区变了」，于是不替换）。Esc、Tab、1–4、⌘C、⌘R 同样全都打进原 App。这是丢文字。
   - 如果面板**是** key window（non-activating 面板可以成为 key，Spotlight 类的面板就是这么做的）：按键到面板，这是我认为唯一合理的做法。但这时设计稿的其他说法要跟着改——见下面第 4 步和任务 3。
   - 如果想保持面板非 key、靠全局拦截：要么 `CGEventTap`（要权限，而且作者记忆库里记过它一创建就弹权限窗），要么面板显示期间临时注册 ⏎ / Tab / Esc / 1–4 这些**不带修饰键**的 Carbon 热键——面板开着的时候我在任何地方都打不出回车和数字。
   设计稿一个字没写选哪种。
4. 假设选了「面板成为 key」。§4.2 写回：先试 AX 设置 `AXSelectedText`。NSTextView 里这一步通常成功。然后「重新读一次确认真的变了」。**没说读什么**。写入成功后选区一般会塌成一个插入点，这时再读 `AXSelectedText` 得到空串，和新文字不相等。照字面实现会判成「没生效」→ 走粘贴兜底 → **文字被插入两次**。
5. 我想撤销，按 ⌘Z。设计稿没说哪条写回路径是可撤销的。通过辅助功能接口写入是否进撤销栈因 App 而异（我没验证）；粘贴是可撤销的。菜单栏的「最近 5 条结果」（§2.7）只存结果，**不存原文**，撤销不了的话原文就找不回来。

### 任务 3：在 VS Code、Slack（Electron）和 Chrome 里的 Gmail 改一句话

1. 读：Chromium 系的 App 默认不构建辅助功能树，除非检测到辅助技术，或者外部进程给 App 元素设了 `AXEnhancedUserInterface` / `AXManualAccessibility`（我没验证当前版本的行为；SDK 里没有这两个常量，上面查过）。所以对**没开 VoiceOver** 的用户，§4.1 第 1 步在 Slack、VS Code、Notion、Obsidian、Chrome 里大概率拿不到焦点文本元素，直接掉到剪贴板兜底。对**我**（VoiceOver 常开），这些 App 的辅助功能树是开着的，走的是第 1 步。也就是说同一个 App，开不开 VoiceOver 走两条不同的路径——§8 的兼容性表只有一列，没有区分。
2. 剪贴板兜底「模拟 ⌘C」：我刚按完 ⌃⌥G（或 ⌃⇧G），手指多半还没松开修饰键。合成的 ⌘C 叠上物理按住的 ⌃⌥，目标 App 可能收到的是 ⌃⌥⌘C。设计稿没写「等修饰键松开」或「合成事件显式指定 flags、用私有事件源」。
3. VS Code 里**没有选区**时按快捷键：§2.4 说进输入模式。但 VS Code 默认在空选区时 ⌘C 会复制**整行**（`editor.emptySelectionClipboard`）。剪贴板兜底会把当前行当成「选中的文字」，面板开始改错，我按 ⏎，它把结果**粘贴到光标处**（没有选区可替换）。原生 App 里空选区 ⌘C 则是一声系统提示音。
4. 「是否可编辑」：§4.1 用 `AXUIElementIsAttributeSettable` 判断。走剪贴板兜底时没有 AX 元素，**这个判断没有来源**。设计稿没说兜底路径下默认当可编辑还是不可编辑。当成可编辑：在 Chrome 的只读网页正文上按 ⏎ 会发一个 ⌘V 到网页（无效或提示音）。当成不可编辑：Slack、Gmail 这些最主要的场景永远没有「替换」按钮。
5. 粘贴兜底「模拟 ⌘V」：如果面板是 key window（见任务 2），合成的 ⌘V 会发到**我们自己的面板**。必须先关掉面板、等原 App 的窗口重新成为 key，再发。写前复查那一次 ⌘C 同理。设计稿的数据流（§3.3）里没有这一步。
6. 「500 ms 后恢复原剪贴板」：Electron 忙的时候处理 ⌘V 可能晚于 500 ms，那粘进去的就是**我原来剪贴板里的东西**。固定延时不可靠（我没实测具体延迟）。另外「保存当前剪贴板」要保存所有条目的所有类型（图片、文件、富文本），延迟提供的数据保存不了，设计稿没写范围。
7. 粘贴兜底之后的「校验」（§3.3 最后一步）：没有 AX 可读，校验什么？没写。
8. 面板位置：兜底路径拿不到选区坐标，§2.2 说「出现在鼠标旁边」。我全键盘操作，鼠标可能停在另一块显示器的角落。面板会出现在离我正在编辑的文字很远的地方（对 VoiceOver 用户不影响，对低视力放大用户和纯键盘的明眼用户影响很大）。

### 任务 4：在终端（Terminal / iTerm）里改一条 git commit -m 的英文

1. 选中终端里已经打出来的一段话，按快捷键。终端的文本区一般能通过 AX 读到选中文字（我没验证各终端的 settable 返回值）。
2. 按 ⏎。若 AX 写入失败掉到粘贴兜底：⌘V 把文字粘到**提示符光标处**，不是替换选区（终端里的选区不是可编辑选区）。如果结果里带换行，shell 会**直接执行**。设计稿的默认「不处理的 App」只有密码管理器，没有对终端做任何特殊处理。
3. 终端开了「安全键盘输入」时合成按键和热键的行为，设计稿没提（我没验证）。

### 任务 5：在 Word 里改论文的一个脚注，文档里已有合作者的修订

1. 前台是 Word。§4.1 的顺序是「AX 优先」，§4.3 又说 Word 用 `content of selection` 读。**哪个先？** 没写清。应该是 Word 完全跳过 AX。
2. 第一次：系统弹「允许 GrammarBuddy 控制 Microsoft Word」。§2.5 说「面板里提前说明」。但读选区就要发 Apple Event，也就是弹窗发生在**面板出现之前或同时**，来不及「提前说明」。如果我点了「不允许」，系统不会再问，设计稿没写这之后面板显示什么、怎么引导去「系统设置 → 隐私与安全性 → 自动化」（可以用 `AEDeterminePermissionToAutomateTarget` 预检，SDK 里有）。另外 Hardened Runtime 下除了 §7 提到的 entitlement，`Info.plist` 还要有 `NSAppleEventsUsageDescription`，没有的话系统直接拒绝、不弹窗（这是我的经验，没在本机验证），设计稿没列。
3. 我的选区在**脚注**里。§4.3 第 1 步记下「选区的起止位置」，第 3 步「替换对应范围」。字典里按位置取范围的命令是 `create range`，直接参数是 document（上面查过），选区的 `selection start` / `selection end` 是相对于**所在 story** 的位置，而选区有独立的 `story type`（正文、脚注、尾注、批注、文本框、页眉页脚）。如果实现成 `create range active document start a end b`，位置会落到**正文 story** 的同一偏移上——改掉的是正文里不相干的文字（`create range` 是否只作用于正文 story 我没验证，但 VBA 里的 `Document.Range` 是这样）。这是静默改错地方。
4. 文档里已有合作者的修订，删除的文字以删除线内联显示。`content of selection` 返回的文字里包不包含那些已删除的文字，取决于修订视图（字典里有 `revisions view` 和 `text retrieval mode`，上面查过；具体行为我没验证）。如果包含：模型看到的是「新旧文字混在一起」的句子；如果不包含：字符串下标和 Word 的字符位置对不上，第 3 步的「原文第 a–b 个字符」全部偏移。
5. 位置换算：Word 的字符位置把段落标记、域代码、脚注引用标记、表格单元格结束符各算作字符；Swift 里按 `Character` 数的下标和它不是一回事（emoji、组合字符、域）。设计稿把「按字符范围替换」列为未验证，这很诚实，但**只验证了「能不能写」，没列「位置对不对得上」**。
6. 写为修订：5 处改动 = 至少 5 次内容设置，加上开关修订 2 次。Word 字典里没有撤销分组（上面查过）。我按一次 ⌘Z 只撤掉最后一个片段，文档停在「改了一半」的状态。设计稿没提撤销。
7. 「写完恢复用户原来的修订开关状态」：如果中途某个片段的 Apple Event 失败或超时，修订开关就停在「开」，要保证失败路径也恢复。没写。

### 任务 6：没有辅助功能权限时走「服务」菜单（§4.4）

1. 在 TextEdit 里选中文字 → 应用程序菜单 → 服务 → GrammarBuddy：改错。
2. §4.4 说「服务由系统把选中文字交给我们、再把结果放回去」。带返回类型的服务是**同步**的：请求方 App 等着我们往剪贴板对象里写结果。这和 §2.1 的「面板 → 我看差异 → 按 ⏎ 确认」对不上。要么服务直接把模型输出写回（不经过我确认，§5.2 的「改动过大不提供替换」也没地方显示），要么服务只接收文字、打开面板、结果只能复制（那就不是「再把结果放回去」）。设计稿没说是哪种，也没说本地模型 5–6 秒时请求方 App 在这期间是什么状态。
3. 新装的服务要等系统扫描到才出现，而且用户可能要在「系统设置 → 键盘 → 键盘快捷键 → 服务」里勾选（是否默认启用我没验证）。Electron App 和 Word 的右键菜单里有没有服务，设计稿说「大多数原生 App」，这个限定词是对的，但对目标用户（Slack、Chrome、Word）来说等于没有。

## 优点

1. **§1.2「不做实时下划线」并给了理由**。这是整个项目最正确的决定。逐 App 适配文字坐标是个无底洞，选中 + 快捷键的模型把 AX 的需求压到了「读选中文字、写选中文字、取一个矩形」这三件事。
2. **§3.2 用 Carbon `RegisterEventHotKey` 而不是事件监听**。不需要权限就能有全局快捷键，`CarbonEvents.h` 里声明还在；这样 §2.6「启动时不弹任何权限窗口」才成立，§4.4 的无权限降级也才有入口。
3. **§4.2 的「写之前重新读一次选区，不一致就不替换」和「写后重读确认」**。大多数同类工具没有这层防护。思路对，只是细节（读什么、兜底路径下怎么读）没写完。
4. **§4.1 剪贴板兜底带 `org.nspasteboard.TransientType`，并且默认排除密码框和密码管理器**。说明作者知道剪贴板管理器这类坑。
5. **§4.3 和 §10 把没验证的事明确标出来，并且给了退路**（分片做不到就整段替换并在面板里说明）。`create range`、可写的 `content`、`track revisions` 在 Word 16.114.4 的字典里都查得到，这条路在字典层面是通的。
6. **§6.5 对 macOS 15 和 26 的翻译接口区分是准确的**，和 SDK 的可用性标注一致。
7. **§3.2 把读写和引擎放进无界面的 `GrammarBuddyKit`**，§8 自带 NSTextView / NSTextField / WKWebView 测试窗口。读写选区这种逻辑只有能自动回归才不会烂掉。
8. **§7 权限最小化**：不沙盒但开 Hardened Runtime，只要一个 Apple Events 的 entitlement，没有多余的。

## 问题清单

| ID | P0/P1/P2 | 设计稿位置 | 问题（在哪个任务的哪一步卡住） | 建议 |
|---|---|---|---|---|
| S1-01 | P0 | §2.1、§2.2、§3.3 | 任务 2 第 3 步。「面板不抢焦点」和「按 ⏎ / Tab / 1–4 / Esc / ⌘C / ⌘R 操作面板」没有说明按键怎么到面板。面板若不是 key window，⏎ 会打进原 App 把选中的文字替换成换行（丢文字），Esc / Tab / 数字也全进原 App。 | 明确写：面板是 non-activating 的 `NSPanel` 子类，`canBecomeKeyWindow` 返回 true，显示时成为 key 但**不激活 App**（原 App 仍是前台 App，菜单栏不变）。不要用事件监听或临时注册无修饰键的全局热键。并把由此带来的后果写进设计：见 S1-02、S1-06。把「non-activating 面板成为 key 后，AppKit / Electron / Chrome / Safari / Word 里选区是否保留」列进 §10，在 M0 就验证。 |
| S1-02 | P0 | 全稿（§2.2、§2.6、§8 都没提） | 任务 1 第 3–4 步。全稿没有无障碍设计。面板若不成为 key，VoiceOver 不会跟过去；差异只用红 / 绿和删除线表达，VoiceOver 念出来是新旧词连在一起，分不清；流式输出期间和完成时没有播报；面板没有标题；「语气▾」「只看结果」「改目标语言」「写为修订 / 直接替换」「插入到原文下方」都没有键盘操作方式。依赖 VoiceOver 的用户完全用不了。 | 加一节「无障碍」：① 面板有可访问标题，打开时成为 key 并把焦点放在结果区；② 流式过程中不逐字播报，完成时用 `NSAccessibilityAnnouncementRequestedNotification` 播报一次「改错完成，2 处修改」或错误原因；③ 结果区的可访问文本用文字描述改动，另外提供一个可用方向键逐条浏览的改动列表（「第 1 处：Their 改为 There」）；④ 所有控件有标签，每个操作都有快捷键且写在设计稿里；⑤ 关闭面板后焦点回到原 App 的原元素；⑥ 新增的文字除了绿色再加下划线，不只靠颜色；⑦ §8 的手工兼容性表加一轮「开着 VoiceOver」。 |
| S1-03 | P0 | §4.3 | 任务 5 第 3–5 步。分片替换按「选区起止位置 + 原文第 a–b 个字符」写回，三个没写的风险都会**静默改错地方**：① 选区在脚注 / 尾注 / 批注 / 文本框 / 页眉里时，`create range` 的直接参数是 document，位置可能落到正文 story；② 选区里已有他人的修订（已删除文字内联显示）时，取到的文字和字符位置对不上；③ Word 的字符位置和 Swift 字符串下标不是同一种计数（段落标记、域、脚注引用标记、emoji）。目标用户（论文、导师修订）正好天天碰到 ①②。 | ① 不要用文档级的绝对位置，用 `text object of selection` 得到的 text range 做基准，在它内部取子范围（或用它的 `set range`）；写之前读 `story type of selection`，不是正文 story 时先退回整段替换，直到验证过。② 每个片段写之前先读回该子范围的 `content`，和差异里的「原文片段」逐字比较，不相等就整次中止并恢复，不要硬写。③ 选区内已有修订、域、表格单元格边界时退回整段替换并在面板里说明。④ 把「位置换算是否对得上（含中文、emoji、脚注引用、已有修订）」单独列进 §10，和「能不能按范围写」分开验证。 |
| S1-04 | P1 | §2.1、§2.6 | 任务 1 第 2 步。默认快捷键 ⌃⌥G / ⌃⌥T 用的是 VoiceOver 的修饰键组合（⌃⌥）。开着 VoiceOver 时默认快捷键会冲突或被吃掉（具体绑定我没验证），而引导第 1 步在用户能改键之前就要求按它。 | 默认换成不含「⌃⌥ 且无其他修饰键」的组合（例如 ⌃⇧G / ⌃⇧T，或 ⌥⇧ 系）；启动时检测 VoiceOver 是否开启（`NSWorkspace.shared.isVoiceOverEnabled`），冲突时在引导里先让用户选快捷键；`RegisterEventHotKey` 返回失败（被占用）时要有提示，设计稿现在没写注册失败的处理。 |
| S1-05 | P1 | §4.2、§3.3 | 任务 2 第 4 步。「写后重新读一次确认真的变了」没说读什么。AX 写入成功后选区通常塌成插入点，重读 `AXSelectedText` 得到空串，会被误判为失败，接着走粘贴兜底，**文字插入两次**。另外 SDK 头文件把 `kAXSelectedTextAttribute` 标为「Writable? No」，写入本来就是各 App 自愿支持的行为。 | 校验改成：写前记下选区范围 (loc, len) 和元素的 `AXValue` 长度；写后用 `AXStringForRange`(loc, 新文字长度) 或 `AXValue` 的对应片段和新文字比较。三种结果分开处理：确认成功；确认没变（才允许走粘贴兜底）；**无法判断**（不走兜底，提示用户并给「复制」）。设计稿里注明 AX 写入不是受文档保证的行为。 |
| S1-06 | P1 | §4.1、§4.2 | 任务 3 第 2、5、6、7 步。剪贴板兜底的几个时序问题都没写：① 合成 ⌘C 时用户还按着热键的修饰键；② 面板是 key 时合成的 ⌘C / ⌘V 会发给面板自己；③ 「500 ms 后恢复剪贴板」是固定延时，App 处理粘贴慢于它就会粘进**旧剪贴板内容**；④ 保存 / 恢复剪贴板的范围（多条目、多类型、延迟提供的数据）；⑤ 粘贴之后「校验」什么。 | ① 合成事件显式设置 flags 只含 ⌘，并等物理修饰键松开（设上限）；② 写回顺序定为：关面板 → 确认原 App 的窗口重新成为 key → 发事件；③ 恢复剪贴板不用固定延时：能读 AX 的用校验结果触发，不能读的把延时放宽并在恢复前确认 `changeCount` 仍是我们写入的那次（期间用户自己复制了东西就不要覆盖）；④ 写明保存全部条目的全部类型，保存不了的情况（延迟数据）说明会丢什么；⑤ 兜底路径下明确「无法校验」，面板提示「已粘贴，如位置不对请按 ⌘Z」。 |
| S1-07 | P1 | §4.1、§2.3、§2.4 | 任务 3 第 3、4 步。走剪贴板兜底时：① 「是否可编辑」没有来源（`AXUIElementIsAttributeSettable` 需要 AX 元素），设计稿没说默认按哪种处理；② 「有没有选区」也判断不了——VS Code 空选区 ⌘C 会复制整行，会被当成选中文字，之后 ⏎ 把结果粘在光标处；原生 App 空选区 ⌘C 是一声提示音。 | 给兜底路径单独定规则：可编辑性标为「未知」，按钮文案用「粘贴到光标处 / 替换选区（未确认）」并把默认动作设为「复制」，由用户显式选替换；对已知 App（VS Code、Slack、Chrome 等）维护一张按 bundle id 的行为表（是否空选区复制整行、是否可粘贴）。把「兜底路径下怎么知道有没有选区」列进 §10。 |
| S1-08 | P1 | §4.1、§8、§10 | 任务 3 第 1 步。没提 Chromium / Electron 默认不暴露辅助功能树这件事（我没验证当前版本），也没决定要不要给目标 App 设 `AXManualAccessibility` / `AXEnhancedUserInterface`（后者有已知副作用）。结果是 Slack、VS Code、Chrome、Notion 这些目标用户最常用的 App，主路径可能恒为剪贴板兜底；并且开着 VoiceOver 的用户和没开的用户走不同路径。Safari 网页正文需要 text marker 那套接口（`AXSelectedTextMarkerRange`、`AXBoundsForTextMarkerRange`），`AXSelectedTextRange` / `AXBoundsForRange` 在网页区域里不一定有（我没验证）。 | §4.1 写明对 Chromium 系的策略（建议 v1 不去改对方的 AX 开关，直接承认走兜底，并把兜底做扎实）；读坐标时加上 text marker 的回退；§8 的兼容性表每个 App 分「VoiceOver 开 / 关」两列，并补上终端、Xcode、TextEdit、信息（Catalyst）、Google Docs、Outlook、Notion、Obsidian。 |
| S1-09 | P1 | §4.2、§2.7 | 任务 2 第 5 步、任务 5 第 6 步。全稿没提撤销。AX 写入是否进目标 App 的撤销栈不确定（我没验证）；Word 分片替换是多步操作，字典里没有撤销分组，一次 ⌘Z 只撤一个片段，文档停在改了一半的状态；菜单栏历史只存结果不存原文，撤销不了时原文找不回。 | 写明每条写回路径的撤销行为；历史记录同时保存原文，并提供「复制原文」；Word 路径记下写入的片段数，面板在替换后短暂显示「撤销本次修改」按钮（调用 `undo` 带次数，字典里有 `times` 参数；次数是否和片段数一一对应需要验证）；把撤销行为列进 §10。 |
| S1-10 | P1 | §4.1、§4.2 | 任务 4。终端里选中的文字不是可编辑选区。粘贴兜底会把结果粘到提示符处，带换行时会被 shell 执行。默认排除列表只有密码管理器。 | 终端类 App（Terminal、iTerm2、Ghostty、Warp、kitty、Alacritty 等，按 bundle id）默认只提供「复制」，不提供替换；任何兜底粘贴前，如果结果含换行而目标可编辑性未知，要求二次确认。 |
| S1-11 | P1 | §4.4 | 任务 6 第 2 步。服务菜单「把结果放回去」和面板的预览确认流程对不上：带返回值的服务是同步的，请求方 App 在等。没说服务是「直接写回不预览」还是「只接收文字、打开面板」。直接写回的话，§5.2 的防跑偏检查没有地方展示，模型 5–6 秒期间请求方 App 的状态也没说。 | 明确选一种。建议：服务只声明发送类型（不声明返回类型），作用是「把选中文字送进面板」，结果只能复制；翻译用系统翻译时足够快，可以另提供一个带返回值的「翻译并替换」。写明服务的超时设置，以及新装后服务何时出现、是否需要用户在系统设置里勾选。 |
| S1-12 | P1 | §2.5、§4.3、§7 | 任务 5 第 1、2、7 步。Word 流程的权限和失败路径没写全：① 第一次读选区就会触发自动化授权弹窗，来不及「在面板里提前说明」；② 用户点了「不允许」之后的状态和恢复引导没写；③ `Info.plist` 需要 `NSAppleEventsUsageDescription`，没列；④ 中途失败时 `track revisions` 的恢复没写；⑤ 文档只读 / 受保护（字典里有 `protection type`、`read only`）时没写；⑥ §4.1 说 AX 优先，§4.3 说 Word 用脚本读，顺序没说清。 | Word 是前台时：先显示面板和说明，用 `AEDeterminePermissionToAutomateTarget` 预检；未决定时由用户点「继续」再触发弹窗；被拒绝时面板显示去「隐私与安全性 → 自动化」的按钮，并降级为剪贴板读 + 只复制。恢复修订开关放在保证执行的清理路径里。写入前检查文档是否只读或受保护。§4.1 里写明 Word 跳过 AX。 |
| S1-13 | P1 | §2.2 | 面板的窗口属性没写：层级、是否跟随所有空间、能否出现在全屏 App 之上。Word 或 Safari 全屏时，默认设置的面板不会出现在全屏空间里。点面板外、切换 App、原 App 窗口移动时面板怎么办也没写。 | 写明：浮动层级，`collectionBehavior` 含 `fullScreenAuxiliary`（加上跟随空间的行为），不在窗口循环里；点面板外或原 App 失去前台时的规则（建议：结果已出就保留并改为「复制」模式，否则取消请求并关闭）。 |
| S1-14 | P1 | §2.2 | 任务 3 第 8 步。拿不到选区坐标时面板「出现在鼠标旁边」。纯键盘用户的鼠标可能在另一块屏幕上。 | 回退顺序改为：选区矩形 → 焦点元素的矩形 → 原 App 焦点窗口的矩形（窗口位置几乎所有 App 都能通过 AX 拿到）→ 鼠标所在屏幕。另外注意 AX 坐标原点在主屏左上角，要换算，多显示器要测。 |
| S1-15 | P1 | §2.1、§2.4 | 面板内的按键分配和系统约定冲突：Tab 在开了「键盘导航」和 VoiceOver 的系统里是「移到下一个控件」，被拿来切换操作后，我没法用 Tab 走到「语气▾」、目标语言这些控件；输入模式（§2.4）里有输入框，数字键 1–4 和 ⏎ 会和打字、输入法选字冲突（中文输入法用数字选候选词、⏎ 上屏）。 | 切换操作改用 ⌘1–⌘4（以及 ⌃Tab 或 ⌘[ / ⌘]）；Tab 留给控件间移动；输入模式下用 ⌘⏎ 提交，⏎ 交给输入框；有未上屏的输入法组字时不响应面板快捷键。 |
| S1-16 | P2 | §4.1 | 「密码框（AXSecureTextField）」是 subrole，不是 role（SDK 里只有 `kAXSecureTextFieldSubrole`）。另外没写：密码框或排除列表命中时，是什么都不做、还是进输入模式；以及这个检查必须在剪贴板兜底**之前**拦住（AX 读不到元素时无法判断是不是密码框，会直接去模拟 ⌘C）。 | 改成查 `AXSubrole`；写明命中后的行为（建议：面板以输入模式打开并说明原因）；AX 完全读不到焦点元素、同时系统处于安全输入状态（`IsSecureEventInputEnabled`，SDK 里有）时不做剪贴板兜底。 |
| S1-17 | P2 | §2.6、§4.4、§7 | 辅助功能授权的细节没写：授权后 App 如何得知（轮询还是重启）；引导第 1 步「试一下」发生在授权之前，这一步是怎么读到引导窗口里的选区的（应当在进程内直接读，不走 AX）；权限和代码签名绑定，贡献者自己编译的未签名 / 临时签名版本每次重编译都会失效。 | 写明：授权页轮询 `AXIsProcessTrusted()` 并自动前进，不要求重启；引导窗口的示例走进程内路径；README 给贡献者一段说明（用固定的开发签名身份）。合成按键前用 `CGPreflightPostEventAccess` 预检。 |
| S1-18 | P2 | §6.5、§10 | 系统翻译的两个没验证的点没列进 §10：① 语言包下载窗口要挂在一个窗口上，挂在不激活 App 的浮动面板（而且是菜单栏 App）上能不能正常弹出、会不会被挡在后面（我没验证）；② macOS 15 的路径（常驻 `.translationTask`，换语言对要换配置并 `invalidate()`）调查机器是 macOS 26.6.1，没在 15 上跑过。 | 两条都加进 §10，M1 验证；准备一个退路：需要下载语言包时改用一个普通的、会激活 App 的小窗口来承载下载流程。在最低支持版本上实测一遍，或者在验证之前把最低版本的说法标为未验证。 |
| S1-19 | P2 | §6.1、§6.2、§7 | 网络相关的系统限制没提：用户把接口地址配成局域网里的机器（很常见，Ollama 跑在另一台机器上）时，macOS 15+ 会要「本地网络」权限，需要 `NSLocalNetworkUsageDescription`；非本机的 `http://` 地址还可能被 App Transport Security 拦（具体豁免范围我没验证）。 | 在 §6.2 写明支持的地址形式和对应的 `Info.plist` 配置；「测试连接」把这两类失败和「服务没开」区分开提示。 |
| S1-20 | P2 | §5.4、§4.1 | 「按下快捷键到面板出现 150 ms 以内」和读选区的顺序有冲突：AX 调用在目标 App 无响应时默认会阻塞数秒；剪贴板兜底自己就要等最多 300 ms；Word 的 Apple Event 也可能慢。 | 先显示面板（位置先用焦点窗口），读取放后台；对 AX 元素用 `AXUIElementSetMessagingTimeout` 设短超时（SDK 里有）；面板有一个「正在读取选中文字」的状态，VoiceOver 也要能听到。 |
| S1-21 | P2 | §4.2 | 「已知限制：富文本编辑器里格式会丢，只在面板里提示」。没说怎么知道当前是富文本（靠 App 列表？靠 AX 属性？），提示出现在替换之前还是之后。 | 写明判定方式（建议按 bundle id 的已知列表起步）和提示时机（替换前，在按钮旁）。 |

P0 共 3 条（S1-01、S1-02、S1-03），P1 共 12 条，P2 共 6 条。
