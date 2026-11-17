# Tom Becker（销售，英语母语，Slack + Chrome 里的 Gmail，现用 Grammarly 免费版）— 原型试用 Round 5

## 结论（评分 4/10；现在这个样子我不会每天用）

改错本身是准的，弹出的面板也清楚（左边划掉、右边加上，一眼能看懂），第一次在某个 App 里用 API 时的询问只要按一次 ⏎，一点不烦。但有三件事让我留在 Grammarly：**换语气会直接把 App 弄崩**（两次都复现）；**每条消息要等 10–25 秒**（这次的「API」其实是本机模型在跑，真 API 可能快很多，但我测到的就是这个）；在 Slack 和 Gmail 里 **⏎ 永远只是复制**，我得自己 ⌘V，比 Grammarly 点一下就改多了好几步。另外「简洁」语气把报价邮件里的「first year」删掉了，这对销售来说是会出事的。

速度说明：机器是 M5 Pro 24 GB，同时有另外 4 个评审在用同一个 LM Studio。说明里的 `engine:api=…|gpt-4.1-mini|sk-qa|local` 在这台机器上会被 LM Studio 拒绝（「Invalid model identifier gpt-4.1-mini」），所以我改成 `…|qwen/qwen3-14b|sk-qa|local`。界面上按 API 显示（橙色询问、「API · api.openai.com」标记），但每次都带 9–24 秒的「思考」。

## 我的任务和过程

### 任务 1：第一次打开，走完引导，选 API

1. `--launch --fresh`，界面设成英文。第 1 步「Which languages do you use?」：母语 English，第二种语言默认填了 Chinese, Simplified（`01-start-0.png`）。**我只会英语**，没有「我只用英语」这个选项，只能硬选一个。不理解为什么非得选，但能继续。→ T5-12
2. 第 2 步「Try translating」：中文示例，按 ⌃⌘T。前两次面板说「GrammarBuddy isn't allowed to read selected text yet」或「No selected text was found」（`03-translate-1.png`）——查下来是测试环境里引导窗口没成为 key window（别的实例在抢前台），不算产品问题。我也读不懂中文，这一步对我没意义，跳过。
3. 第 3 步「Allow reading selected text」：说明清楚，提到 Slack、Chrome 会经过剪贴板。按规则不去系统设置，直接 Continue。
4. 第 4 步「Choose an AI」：两张卡片，API 一边写「Fastest, no memory used / Selected text is sent to that service; pay per use」。我会选这个（`06-api-card.png`），有「Create an API key on OpenAI」链接，一个 key 输入框、一个 Test。
   - **点 API key 输入框会把测试接口卡死**（SwiftUI 文本框的鼠标跟踪等不到真的松开），只能 `pkill` 自己的实例重开，记作测试限制。改用 `engine:api` 配一个假的真 OpenAI key。
   - 输入框空着点 Test：红字「Paste an API key」，但下面同时有绿色「✓ Set up: api.openai.com · gpt-4.1-mini」（`14-test-empty.png`）。一红一绿，我不知道到底配好没有。→ T5-14
5. 第 5 步「Try Fix」：选中示例句，⌃⌘G。
   - 我不小心按了一下 Tab，示例句被换成一个制表符，再按 ⌃⌘G，面板显示「Original (0 words · 0 characters)」，还问我「要把 GrammarBuddy 里的文字发给 api.openai.com 吗？」（`16-tryfix-0.png`、`16-tryfix-1.png`）。空的东西不该问。Back → Continue 能把示例句恢复。→ T5-13
   - 正常选中后，第一次询问（`18b-consent.png`）：「Text you select in GrammarBuddy will be sent to api.openai.com. Allow?」上面的 Original 就是会发出去的原文，很清楚。点「Just this once」，假 key 发给真 OpenAI：「api.openai.com：The API key was rejected」加「Open Settings」按钮（`19-badkey.png`）。看得懂；冒号是中文全角的。→ T5-15
   - 换成本机模拟 API 后重试：**21.9 秒**（21 秒在思考）出结果，4 处改动全对（`23b-demo-result.png`）。⏎ 真的替换了引导窗口里的文字，小条「Replaced. ⌘Z to undo」（`24-after-enter-0.png`）。
6. 点 Done，引导结束。**从打开到第一次成功：5 步引导、约 8 次点击 + 一次 API 询问 + 等 22 秒。** 比装 Grammarly 插件麻烦，但可以接受。

### 任务 2：Slack 里改错（预设 + 我自己的消息），第一次在 Slack 用 API

1. `simulate:slack`（「hey team, i has finished the deck for tomorow…」）。**0.8 秒**出现询问「Text you select in Slack will be sent to api.openai.com. Allow?」（`26-slack-consent.png`），蓝色按钮「Allow in Slack」，⏎ 就是允许。我按 ⏎。
2. 按 ⏎ 后 **11.6 秒**出结果（思考 10 秒）。6 处改动：Hey / I have / tomorrow. Can / Friday / It's / 句末句号（`27-slack-fix.png`）。底栏：⏎ copy，⌘⏎ unavailable，理由「You left the panel while it was working」。我没离开——是别的测试实例抢了前台（见「测不了的部分」），真实使用时理由应该是「Can't confirm this place is editable」。
3. 同一段再跑一次：没有再问（Slack 已经允许，好），**12.7 秒**。但这次结果是「hey team, **i** have finished … before **friday**? it's …」（`28-slack-fix2.png`）。同一句话两次结果不一样，第二次把「i」这种明确的错留下了。→ T5-09
4. 我自己的消息：「Hi Mark - just wanted to folow up on our call yesterady. Pricing for 50 seats is $18/user/month, I can do 15% off if we sign before Nov 30. lmk if that works for you guys」。只改了 folow→follow、yesterady→yesterday，「lmk」「you guys」都保留了，**这正是我要的**：不把我的 Slack 消息改成公文。思考 20 秒。
5. 多行消息（Globex 通话要点，带「- 」列表）：**22.4 秒**。7 处改动里有 3 处是在每行末尾加了两个空格（Markdown 的换行写法），差异视图里显示成「↵ → ␣␣↵」，列表也被挤成一段（`52-slack-multiline.png`）。还出现「⚠ 1 protected item(s) changed」，我找不到是哪一处。→ T5-04、T5-10

### 任务 3：Chrome 里的 Gmail 改错，体验 ⏎ 是复制、⌘⏎ 要确认

1. `simulate:gmail-chrome`。第一次在 Chrome 用 API，又问一次（`30-gmail-consent.png`），⏎ 允许。**10.8 秒**出结果，4 处改动全对（`31-gmail-fix.png`）。
2. 这次面板一直在前面，底栏写「Can't confirm this place is editable, so ⏎ copies」，⏎ 是 copy，⌘⏎ 是 replace。我懂：⏎ 不会把东西发出去，也不会弄乱，**这点我放心**。
3. 按一次 ⌘⏎：底栏变成「1 formatted item(s) in the selection (links, bold…) will be lost. Press ⌘⏎ again to confirm」（`32-cmdenter-1.png`）。这时面板底部的按钮被截掉了一半。我也不知道哪个是链接（原文里看不出来）。→ T5-10、T5-11
4. 再按一次 ⌘⏎：面板收起，小条「Pasted. Press ⌘Z if it landed in the wrong place (QA simulation)」。
5. 第二封 Gmail（「our trail ends this friday… so their is no gap」）：trail→trial、Friday、there，全对。⏎ 仍然是复制，**没有出现设计里说的「上次替换的位置对吗？对的话以后 ⏎ 直接替换」**（代码里也搜不到）。也就是说在 Gmail 和 Slack 里我永远要多按一步。→ T5-03

### 任务 4：换语气（friendly / concise）

1. `simulate:slack+tone`：第一次用语气，**没有让我选**，直接按 Formal 跑了（`34-tone-first.png`），16 秒后得到「Dear Team, I have completed the deck for tomorrow. Kindly review it prior to Friday; it is located in the shared drive.」——这在 Slack 里发出去会被同事笑。（代码里只有从面板按 ⌘4 切过去才弹列表；直接以语气开始时不弹。）→ T5-08
2. 在这个结果上换成 Friendly（`panel:tone=friendly`）：**App 直接崩溃**。重开后在结果上换成 Concise：**又崩了**。两次崩溃报告都是 `ChangeChip.body.getter PanelView.swift:454`，`m.changes[index]` 数组越界：重新跑的时候改动列表变短了，旧的改动小块还在按旧序号取。同一时间其他评审的崩溃报告也是这个位置。→ **T5-01**
3. 重开后直接以 Friendly 开始：**25.5 秒**。「Hi team! I've finished the deck for tomorrow. Could you take a quick look before Friday? It's in the shared drive!」（`37-tone-friendly.png`）——好，这就是我会发的样子。
4. 一封 128 词的跟进邮件用 Concise（我造的 Gmail 文字，`38-gmail-concise.png`）：**14.1 秒**。
   - 原文在面板里默认展开，长邮件把整个面板占满，结果被挤到最下面，要滚动才看得到（`38`、`39-concise-result.png`）。点「Original」想收起没成功。→ T5-06
   - 结果只短了约三分之一，还**把「15% off for the first year」改成了「a 15% discount for signing before Nov 30」，「first year」没了**。数字检查没报。我要是没细看就发出去，客户会以为是永久折扣。→ T5-05
   - 复制下来的文字每行末尾多了两个空格（`pbpaste` 看到「Hi Sarah,␣␣」），还换成了弯引号和破折号。→ T5-04
5. ⏎ 复制：底栏「Copied. The original is unchanged」，面板留着（`41-after-copy.png`）。清楚。

### 任务 5：处理中离开面板（panel:leave）

1. Slack 消息「@channel heads up - Acme just signd the renewel, 120 seats for 2 yrs!! … couldnt of done it without her」，1 秒后 `panel:leave`（`42-leave-working.png`）。请求没被取消，继续跑完（约 13 秒思考），结果 3 处全对：signed、renewal、couldn't have，「@channel」「!!」「yrs」都保留（`43-leave-done.png`）。
2. 之后只能复制，⌘⏎ 灰掉，理由「You left the panel while it was working, so the selection can't be confirmed」。这个我能理解：Slack 里我可能已经点到别的频道了，粘错地方更糟。**能做的事：⏎ 复制，回 Slack 自己 ⌘V。**
3. 问题是，面板上那句「Please don't click elsewhere while this runs, or the result can only be copied」从出现到结果出来之后一直挂着（`31`、`43`）。等 10–20 秒不准点别处，对我这种一边回三个人消息的人来说太难了。→ T5-07

### 任务 6（附带）：新 App 里点「Don't allow」，以及设置里粘贴假 key

1. Messages（经辅助功能读到，可编辑纯文本）：询问出现（`45-messages-consent.png`），点「Don't allow」，面板直接消失，什么也没说。下次再选还会再问，但询问上写着「Your choice is remembered per app」。→ T5-16
2. 允许后 **16.9 秒**出结果（sory→sorry、coffe→coffee），⏎ 是「replace」，记录为「replace via accessibility」（`48-messages-done.png`）。
3. 设置 → AI：粘贴一个假 key，点 Test，红字「The API key was rejected」（`51-settings-test.png`）。说法清楚，但没告诉我下一步（是不是没复制全？账户没充值？）。

### 计时汇总（从 simulate 或允许那一下，到结果出来）

| 场景 | 时间 | 其中思考 |
|---|---|---|
| 询问出现 | 0.8 s | — |
| 引导示例（14 词） | 21.9 s | 21 s |
| Slack 预设（21 词），两次 | 11.6 s / 12.7 s | 10 / 12 s |
| Slack 我的报价消息（36 词） | 约 22 s | 20 s |
| Slack 多行列表（25 词） | 22.4 s | 21 s |
| Gmail 预设（22 词） | 10.8 s | 10 s |
| Gmail 第二封（24 词） | 约 10 s | 9 s |
| 语气 Friendly（Slack 21 词） | 25.5 s | 24 s |
| 语气 Concise（Gmail 128 词） | 14.1 s | 13 s |
| Messages（13 词） | 16.9 s | 16 s |

中位数约 14 秒，几乎全是模型思考。Grammarly 是边打边出下划线，0 秒。

## 模型结果

| # | 原文 | 输出 | 对不对 | 敢不敢直接用 |
|---|---|---|---|---|
| 1 | Their are three reason why this approach work better then the previous one [12]. | There are three reasons why this approach works better than the previous one [12]. | 对 | 敢 |
| 2 | hey team, i has finished the deck for tomorow, can you have a look before friday? its in the shared drive | 第一次：Hey team, I have finished the deck for tomorrow. Can you have a look before Friday? It's in the shared drive. | 对 | 敢 |
| 3 | 同上（第二次） | hey team, i have finished the deck for tomorrow, can you have a look before friday? it's in the shared drive | 漏改「i」→「I」，friday 没大写；和第一次不一致 | 敢发，但不放心 |
| 4 | Hi Mark - just wanted to folow up … yesterady. Pricing for 50 seats is $18/user/month, I can do 15% off … lmk if that works for you guys | 只改 follow、yesterday，其余照旧 | 对，保留了我的口气 | 敢 |
| 5 | quick recap from the Globex call:\n- they want SSO + audit logs befor they sign\n- budget aproved for Q1\n- next step: send security questionaire by tues | before、approved、questionnaire、tues→Tuesday，**每行末尾加两个空格** | 拼写对；tues→Tuesday 改了我的写法；行尾空格是垃圾 | 敢用，但差异里一半是噪音 |
| 6 | Hi Anna, thanks for you're quick reply. I have attach the contract draft, please let me know if their are any problem. | … your quick reply. I have attached … if there are any problems. | 对 | 敢 |
| 7 | Hey Jordan, quick reminder that our trail ends this friday. … so their is no gap in service? | trial、Friday、there | 对（trail→trial 这个 Grammarly 免费版常常漏） | 敢 |
| 8 | @channel heads up - Acme just signd the renewel, 120 seats for 2 yrs!! … couldnt of done it without her | signed、renewal、couldn't have；@channel、!!、yrs 保留 | 对 | 敢 |
| 9 | running 10 min late, sory! grab a table and order me a coffe | sorry、coffee | 对，没给我加大写 | 敢 |
| 10 | 语气 Formal（Slack 预设） | Dear Team, I have completed the deck for tomorrow. Kindly review it prior to Friday; it is located in the shared drive. | 语法对，但不是我要的语气（我没选 Formal） | 不敢 |
| 11 | 语气 Friendly（Slack 预设） | Hi team! I've finished the deck for tomorrow. Could you take a quick look before Friday? It's in the shared drive! | 好 | 敢 |
| 12 | 语气 Concise（128 词报价邮件） | 约 85 词，… with a 15% discount for signing before Nov 30 … | **丢了「for the first year」**，改变了报价条件；行尾加空格、弯引号、破折号 | 不敢 |

## 优点

1. **改错准，而且不改我的口气。**「lmk」「you guys」「yrs!!」「@channel」都留着，trail→trial、couldnt of→couldn't have 这种 Grammarly 免费版常漏或者只给付费建议的，它都改了。
2. **⏎ 不会坏事。** 在 Slack、Gmail 里 ⏎ 只是复制，底栏一句话说清楚为什么；⌘⏎ 要按两次，第一次会说会丢什么。我最怕的「按回车把半成品发出去」不会发生。
3. **每个 App 问一次，一点不烦。** 我一天只用 Slack 和 Chrome，问两次就完了；按钮默认是「Allow in Slack」，⏎ 就过。询问上面直接显示「这段就是要发出去的原文」，比 Grammarly 什么都不说要坦白。
4. **差异视图一眼能看懂。** 红删绿加，「4/4 accepted」，⌘D 切到纯结果。
5. **出错的说法是人话。**「The API key was rejected」+「Open Settings」，不是一串 HTTP 错误码。
6. **离开面板不丢结果。** 处理中切走，回来结果还在，⏎ 照样能复制。

## 问题清单

| ID | 级别 | 位置 | 现象（复现步骤） | 建议 | 截图 |
|---|---|---|---|---|---|
| T5-01 | P0 | 面板，换语气 / 重新跑 | 有结果后换语气（`panel:tone=friendly` 或 `=concise`）→ App 立刻崩溃。2/2 复现。崩溃报告：`ChangeChip.body.getter PanelView.swift:454`，`m.changes[index]` 越界（新结果的改动比旧的少）。同一时间别的评审也有相同的崩溃报告 | ChangeChip 不要按序号取，或者先判断越界；重新跑的时候先清空改动列表再渲染。⌘1–⌘4、⌘R 也要一起测 | `35-tone-formal.png`（崩溃前最后一屏） |
| T5-02 | P1 | 速度 / 「API」引擎 | 每条消息 10–25 秒，几乎全是思考（9–24 s）。界面写「Waiting for the model… N s」，不是「Thinking」。说明里的 `gpt-4.1-mini` 模拟配置在 LM Studio 里会被拒绝 | 用真 API 重新测速度，这是我换不换的关键：超过 3 秒我就回 Grammarly 了。改错类请求关掉思考；思考状态按设计写「Thinking · 8 s」；修正测试说明里的模型名 | `42-leave-working.png` |
| T5-03 | P1 | Slack / Gmail 的 ⏎ | ⏎ 每次都只是复制，要自己切回去 ⌘V，或者 ⌘⏎ 按两次。设计 §2.4 里那句「上次替换的位置对吗？对的话以后 ⏎ 直接替换」没做（代码里搜不到）。和 Grammarly 点一下就改比，每条多 2 步 | 把这个询问做出来；至少在 Slack（纯文本）里，用过一次 ⌘⏎ 之后让用户选「以后直接替换」 | `44-gmail-second.png` |
| T5-04 | P1 | 输出清洗 | 多行结果每行末尾多两个空格（Markdown 换行）。Slack 列表 7 处改动里 3 处是这个；复制进剪贴板的文字也带着。Concise 还换成了弯引号和破折号 | 原文行尾没有空格的，清洗时去掉；改错不要改引号样式 | `52-slack-multiline.png`、`38-gmail-concise.png` |
| T5-05 | P1 | 语气 Concise | 报价邮件「15% off for the first year」→「15% discount for signing before Nov 30」，丢了「first year」。检查没报，也没提醒 | 语气 / 润色的提示词要求保留所有条件和数字的范围；跑偏检查要比对「for the first year」这类限定语，至少提醒「删掉了一个条件」 | `38-gmail-concise.png` |
| T5-06 | P1 | 面板，长原文 | 经剪贴板读到的原文默认展开，128 词的邮件把面板占满，结果在下面要滚动才看得到；点「Original」收不起来（测试接口里） | 结果出来后自动收起原文，或者原文超过 3 行只显示 3 行 | `39-concise-result.png` |
| T5-07 | P2 | 面板提示 | 「Please don't click elsewhere while this runs…」在结果出来之后一直挂着。等 10–20 秒不准点别处太难。另外在测试环境里，别的实例抢一下前台就被算成「离开了」，⌘⏎ 被禁用；真实使用时日历提醒、Zoom 弹窗抢前台会不会也这样？ | 结果出来就去掉这句；只把用户自己切换 App 或点击别处算「离开」 | `27-slack-fix.png`、`43-leave-done.png` |
| T5-08 | P2 | 语气第一次 | 以语气开始（默认操作是语气，或 `+tone`）时不弹列表，直接用 Formal，Slack 里出来「Dear Team… Kindly review」 | 不管从哪进来，第一次都先让用户选；Slack 里默认 Friendly 更合理 | `34-tone-first.png`、`35-tone-formal.png` |
| T5-09 | P2 | 改错一致性 | 同一段 Slack 文字跑两次：一次改了 I / Friday / 大写开头，一次留下「i have」「friday」 | 温度设 0；「i」→「I」这种不是风格，应该一定改 | `27-slack-fix.png`、`28-slack-fix2.png` |
| T5-10 | P2 | 检查提示 | 「⚠ 1 protected item(s) changed」不说是哪一处；⌘⏎ 的确认「1 formatted item(s) … will be lost」也不说是哪个链接。「item(s)」读起来像机器 | 在改动上加角标（设计 §3 已有），文案按单复数写 | `52-slack-multiline.png`、`32-cmdenter-1.png` |
| T5-11 | P2 | 面板布局 | 第一次按 ⌘⏎ 后底栏变成两行，面板没长高，「4/4 accepted / copy / replace」被截掉一半 | 底栏变高时面板跟着长 | `32-cmdenter-1.png` |
| T5-12 | P2 | 引导第 1 步 | 只说英语的人也必须选第二种语言，默认是 Chinese, Simplified | 加「I only write in English」，或者允许第二种为空、翻译步骤自动跳过 | `01-start-0.png` |
| T5-13 | P2 | 引导第 5 步 | 示例文字可编辑，误按一个键就没了；选中空白再 ⌃⌘G，面板显示「0 words」并询问要不要发给 api.openai.com | 示例文字只读，或者加「恢复示例」；空选区直接显示「没有选中文字」，不要问 | `16-tryfix-0.png`、`16-tryfix-1.png` |
| T5-14 | P2 | 引导 API 卡片 | 同一时间红字「Paste an API key」和绿字「Set up: api.openai.com」 | 已有配置时输入框显示「已保存的 key ••••」，Test 用已保存的 key | `14-test-empty.png` |
| T5-15 | P2 | 出错文案 | 英文界面里是全角冒号「api.openai.com：The API key…」；没说下一步该检查什么 | 用半角冒号；加一句「Check you copied the whole key, and that the account has credit」 | `19-badkey.png`、`51-settings-test.png` |
| T5-16 | P2 | 询问「Don't allow」 | 点了之后面板直接消失，没有任何说明；下次还问，但询问上写着「Your choice is remembered per app」 | 关掉前说一句「Not sent. Translation still works」；文案改成「Allow 会被记住」 | `45-messages-consent.png` |
| T5-17 | P2 | 播报（VoiceOver） | 「Fix done, 4 changes. Return will copy because Can't confirm this place is editable, so ⏎ copies」：句中大写，还把「⏎」念出来 | 播报单独写一版文案 | events.log |

## 测不了的部分会不会让我担心

- **真的写回 Slack / Gmail**：这是我最担心的。我关心的就是 ⌘⏎ 之后文字有没有落在 Slack 的输入框里、会不会多一个换行把消息发出去。设计里说动作在松开按键时才执行，但没看到真的效果。在真机上看到之前我不会对着客户邮件用 ⌘⏎。
- **真 API 的速度**：这次的「API」是本机模型，每次都在思考。如果真的 gpt-4.1-mini 是 1–2 秒，上面的速度评价会好很多，分数能到 6；如果也要 10 秒，我不会换。
- **剪贴板**：Slack 和 Chrome 靠模拟 ⌘C 读，引导里说会短暂经过剪贴板。我不用剪贴板管理器，不担心；但「⏎ 复制」会覆盖我剪贴板里原来的东西（比如刚复制的报价链接），这个已经真的发生了。
- **测试接口本身的限制**（不计分）：点引导里的 API key 输入框会让 App 卡住，只能 pkill 重开，所以在引导里没法真的粘贴 key；引导窗口经常不是 key window，⌃⌘T / ⌃⌘G 读不到示例文字，要先 `focus` 再试；别的评审实例抢前台，导致大多数 Slack 结果被算成「离开了面板」，所以我只在 Gmail 那一次看到了不离开时 ⌘⏎ 的样子。
- **和 Grammarly 比**：Grammarly 免费版边打边提示、点一下就改，我不用复制粘贴；GrammarBuddy 的优势是能整段换语气、能看到文字发去哪。语气这个功能我真的想要（Friendly 那条很好），但前提是不崩、够快、不删我的报价条件。
