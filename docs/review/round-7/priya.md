# Priya（市场经理，英语非母语，Grammarly 付费用户）— 用着顺不顺 Round 7

## 结论（评分 5/10；一句话：我会不会开着它写东西）

标记本身比我预期的好：两封邮件 18 处标记里没有一处把对的改成错的，人名、产品名、日期、金额一个都没碰。但在我的测试条件下（Chrome 在后台），「采用」8 次里只成功 1 次，其中删除类的建议失败时没有任何提示，卡片原地重开，⏎ 按三次都停在同一条。再加上「简洁」语气一个字没删、「润色」和「改错」结果一样，**现在我不会用它替掉 Grammarly**；采用在前台 Chrome 里确认可靠之后，我愿意开着它写内部消息。

## 我试了什么

- 宿主：Chrome 里的本地测试页（`qa/host.sh chrome`），全程在后台，没有切到前台。当时最前面的是系统的 UserNotificationCenter。
- 引擎：LM Studio / qwen3-14b（共用），`gb_live_use_configured=true`。同时有 wang、ines、sam 三个实例在用同一个模型。
- 文字：`/tmp/gbtest/priya-1.txt`（给客户 Mr. Okafor 的跟进邮件，BrightLoop Analytics，$4,800，25 users，November 27，15%，Daniel Reyes）；`/tmp/gbtest/priya-2.txt`（给同事 Mei-Ling 的消息，LumaDesk，December 3，12,500 EUR，Tomasz，Sanjay）。

| 步骤 | 做了什么 | 看到什么 |
|---|---|---|
| 1 | 邮件 1，`live:on`，每 2 秒 dump | 0–32 秒一直是「0 条，8 句排队」；**约 34 秒第一条，约 40 秒 9 条全部标完** |
| 2 | `live:next`（⌃⌘J） | 卡片 `to → (delete)`，1/9，Accept / Ignore / Ignore sentence（`shots/priya/p1-card0-1.png`） |
| 3 | ⏎ ⏎ ⏎ | 三次都 `used=true`，卡片三次都还是 `to → (delete)`，文字没变，没有提示（events.log 里没有 toast） |
| 4 | Esc，`live:accept=1`（cost → costs） | 文字没变；提示「Couldn't replace this one (the text may have changed)」 |
| 5 | ⇥ 连按 10 次 | 按顺序 cost → include → have → until → a → question → to → hear，然后绕回第一条，没有跳错或漏掉 |
| 6 | 打开第 5 条（插入 a）看卡片；按 `a`；按空格 | 卡片只显示「→ a」（`p1-card5-1.png`）；`a` 和空格都 `used=false`，卡片关闭 |
| 7 | `live:accept=0`（删除 to）、`=5`（插入 a）、`=7`（hear → hearing）、`=6`（插入 to）、`=1`（cost → costs） | **只有插入 a 成功**：文字变成「offer you a 15% discount」，标记 9 → 8，其余标记位置没乱，没有冒出新建议。另外四次文字都没变，日志里没有新的提示 |
| 8 | 邮件 2（模型已热），`live:on` | **约 3.7 秒第一批（2 条），约 8.4 秒 9 条全部标完** |
| 9 | 邮件 2 上 `live:open=0`、⇥、`live:open=4`、⇥、Esc；`live:z` | 都正常；下划线层紧贴在 Chrome 窗口上面一层 |
| 10 | simulate 润色邮件 1 第二段（via clipboard） | **35 秒**才出结果（前 25 秒面板是空的）；5 处改动，和实时标记完全一样；⏎ 变成 copy，理由「You left the panel while it was working」（`p3-polish.png`） |
| 11 | simulate 语气 friendly（via accessibility，editable） | 4 秒；8 处改动：5 处改错 + I've / you'd 两个缩写；⏎ = replace |
| 12 | 语气 concise | 4 秒；输出和改错一模一样，53 词变 55 词，没有删任何东西（`p5-concise.png`） |
| 13 | 面板里按 ⏎ | 记录为「replace via paste … (QA simulation)」，面板关闭 |

「忽略」和「这句都忽略」：按钮点不了。我想点的是：邮件 1 的 `have → has`（Our team have，英式用法没错，我想「忽略」）；邮件 2 的 `spoke → spoken`（这句应该整句改成 I spoke，我想「这句都忽略」然后自己改）。我只用 ⇥ 跳过了它们。⇥ 跳过后标记还在，所以它不等于忽略。

## 七个问题的回答

1. **等多久**：第一次 34 秒 / 40 秒，第二次 3.7 秒 / 8.4 秒。第一次那 32 秒里屏幕上什么都没有，我会以为它没开。这个慢可能是共用模型在加载或排队，我分不出来，所以不给速度下结论；但「在查」的时候应该有个可见的提示。热了以后的 4 秒 / 8 秒我能接受，Grammarly 是边打边出。
2. **标得对不对**：18 处里 16 处对，2 处半对（见下节），0 处改错，0 处碰专有名词、日期、金额。漏了 4 处：`on last Thursday`、`we have discussed`（应为 we discussed）、`I have spoke … yesterday` 的时态、`untill Friday` 只改了拼写没改成 by（而邮件 1 里同样的错改成了 by，前后不一致）。
3. **键盘流程**：⌃⌘J 和 ⇥ 顺，⇥ 到最后一条会绕回开头，Esc 符合直觉，继续打字时卡片自己让开、键照常进 App，这个很好。⏎ 这一条我没走通（步骤 3）。另外 Esc 之后再按 ⌃⌘J 是从光标处重新开始，不是从我刚才看到的那条继续。
4. **采用之后**：成功的那一次，文字真的改了，其余 8 条位置没乱，没有越改越多。但 8 次里只成功 1 次。Chrome 不在最前面时，代码里的粘贴后备路径会直接拒绝（`WriteBack.paste` 检查前台 App），所以这很可能是测试条件造成的，前台是否正常我没法确认。即使如此，删除类建议失败时不报错、卡片原地重开，这个行为本身是错的。
5. **段落改写**：差异一眼看得懂（红色删除线 + 绿色下划线），数字和人名没动，敢按 ⏎。但「润色」什么都没润色，只是改错；`which I attached` 这种我希望它顺一下的地方没动。
6. **翻译并润色**：这次任务没让我测，没测。
7. **整体**：标记的克制让我有好感，像一个不多嘴的朋友。会让我关掉它的三步：第一次 30 多秒没反应；按 ⏎ 没改也不说话；等了 35 秒的润色最后只能复制。

## 和 Grammarly 比

更顺的地方：
- 不碰我的产品名和人名。Grammarly 经常给 BrightLoop、Mei-Ling 画红线。
- 不推销语气升级，不弹「升级 Premium」，建议少而准。
- ⌃⌘J → ⇥ 可以完全不用鼠标过一遍，Grammarly 做不到。
- 文字留在本机，给客户的报价邮件我更放心。

更别扭的地方：
- 卡片没有解释。Grammarly 会说「缺少冠词」，这里只有 `→ a`，我学不到东西，插入类的甚至看不出加在哪。
- Grammarly 是边打边标，这里第一次要等半分钟且没有任何「正在查」的提示。
- Grammarly 点一下一定生效；这里采用失败了不说话。
- Grammarly 的「缩短这句」真的会缩短；这里的 Concise 没有效果。
- 时态配合时间状语这类错（have spoke yesterday），Grammarly 能改对整句，这里只改了一半。

## 模型的建议逐条评

邮件 1（9 条）：

| 原词 → 新词 | 评 |
|---|---|
| joining ~~to~~ our call | 对 |
| cost → costs | 对 |
| include → includes | 对 |
| Our team have → has | 没必要（英式用法可接受），美式客户面前可以改 |
| sign until → by November 27 | 对，这是我最常犯的错 |
| offer you + a 15% discount | 对 |
| question → questions | 对 |
| would like + to schedule | 对 |
| forward to hear → hearing | 对 |
| 漏：on last Thursday；we have discussed；follow up about（应为 on）；which I attached（应为 have attached） | 前两处是明确的错 |

邮件 2（9 条）：

| 原词 → 新词 | 评 |
|---|---|
| have spoke → spoken | 半对：形式对了，但有 yesterday，应该是 I spoke |
| he agree → agreed | 对 |
| budget are → is | 对 |
| a → an approval | 对（更好是去掉冠词，但不算错） |
| untill → until | 半对：拼写对了，这里应该是 by Friday |
| didn't received → receive | 对 |
| remind ~~to~~ Sanjay | 对 |
| invitation go → goes | 对 |
| tomorow → tomorrow | 对 |

润色 / 语气（邮件 1 第二段）：润色 = 上面同样 5 处；friendly 多了 I've、you'd 两个缩写，自然，可以用；concise 没有变短。三次都保留了 November 27、15%、Daniel Reyes。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| P7-01 | P0 | 实时标记 · 采用（Chrome） | 邮件 1，`live:next` 后 ⏎ ×3：每次 `used=true`，卡片仍是 `to → (delete)` 1/9，文字不变，没有提示。`live:accept=0` 同样静默失败。⏎ 被吃掉了，什么也没发生，我会一直按 | 删除类采用要核对文字真的变了才算成功；失败就提示并跳到下一条，不要原地重开。看代码推测原因（没验证）：`axReplace` 用「新文字 == 该位置的文字」做验证，新文字为空时恒成立 |
| P7-02 | P0（前台待确认） | 实时标记 · 采用（Chrome） | Chrome 在后台时，替换类（cost → costs、hear → hearing）全部失败，插入类 2 次成功 1 次。8 次采用共成功 1 次 | 在前台 Chrome 里用这两封邮件重跑一遍逐条采用；若只是后台才失败，提示语应写「Chrome 不在最前面」，现在写的是「文字可能已经变了」，会误导 |
| P7-03 | P1 | 语气 · Concise | 邮件 1 第二段，输出和改错完全相同，53 词变 55 词 | Concise 必须真的变短；没变短就说「已经很简洁」 |
| P7-04 | P1 | 润色 | 润色结果和改错、实时标记完全相同（5 处） | 润色要和改错有区别，否则去掉一个按钮 |
| P7-05 | P1 | 实时标记 · 等待 | 第一次 32 秒内 0 条标记，屏幕上没有任何「正在查」的迹象 | 检查进行中在文本框角落放一个小状态点；模型在加载时说出来 |
| P7-06 | P1 | 面板 · 润色 | 润色等了 35 秒（前 25 秒面板空白），期间面板失去焦点，结果 ⏎ 只剩 copy，⌘⏎ 不可用 | 等这么久我一定会点别处。选区没变就仍然允许替换；空白期间显示进度 |
| P7-07 | P1 | 卡片 · 插入类 | 卡片只显示 `→ a` 或 `→ to`，看不出加在哪两个词之间 | 显示上下文：`you a 15%`、`like to schedule` |
| P7-08 | P2 | 卡片 | 没有一句话的原因（冠词、主谓一致、介词） | 加一行灰色小字，这是非母语用户留在 Grammarly 的主要理由 |
| P7-09 | P2 | 模型 | 时态和时间状语不配合的没处理：`have spoke … yesterday` → spoken；`we have discussed` 漏；`untill Friday` 只改拼写，而另一封里 until → by | 提示词里加「完成时 + 过去时间」「until / by 截止日期」的例子 |
| P7-10 | P2 | ⌃⌘J | Esc 关掉第 4 条后再按 ⌃⌘J，回到光标后的第一条，不是接着第 5 条 | 记住上次看到哪条，从那里继续 |
| P7-11 | P2 | ⇥ | ⇥ 跳过后标记还在，绕一圈又回来；键盘上没有「忽略」 | 给忽略一个键（例如 ⌫ 或 ⌘⏎ 之外的单键），或 ⇥ 跳过的本轮不再回来 |
| P7-12 | P2 | 失败提示 | 连续多次采用失败，events.log 里只有 1 条 toast | 每次失败都要有反馈 |

## 测不了的

- 真实的鼠标点击：「忽略」「这句都忽略」两个按钮没点成，忽略之后标记会不会回来不知道。
- Chrome 在最前面时的采用。规则不许切前台，所以 P7-02 是不是真问题我无法确认；P7-01 的静默失败在后台确实发生了，前台是否一样也没确认。
- 下划线画得好不好看、和字对不对齐：只看了坐标（同一行的标记 y 相同，宽度和词长相符），没看到 Chrome 的画面。
- 真的在输入框里打字时标记怎么跟着变。
- Gmail 真正的写信框（富文本），我每天用的就是它，这次只测了普通 textarea。
- 翻译并润色：没测。
- 速度：四个实例共用一个模型，34 秒和 35 秒这两个数字不能当作产品的真实速度。

备注：simulate 打开面板时 `appIsActive` 变成 true，也就是测试实例自己成了前台 App，这可能打扰到正在用电脑的人。两个测试页的标签页还留在 Chrome 里，我没有去关。
