# Marta（西英双语记者兼译者）— 用着顺不顺 Round 8

## 结论（评分 8/10）

**实时标记我会一直开着；润色现在敢按 ⏎ 了；「翻译并润色」仍然只当初稿。**
上一轮的两个 P0 都改好了，而且改法是对的：引语里的原话在实时标记里完全不碰，在面板里默认不采用、有橙色引号角标和一行说明；`por que → porque` 是一条标记，采用后文字正确。键盘流程全套（连按 ⏎、⇥ 不绕回、⌫ 忽略、末尾多按的 ⏎ 被吃掉）没有一处出错。扣的 2 分：「翻译并润色」和上一轮几乎一样（破折号仍留在英文里、`a priority`、`la alcalde`），倒问号 / 倒叹号和 `el → él` 还是老样子，改错里删掉重复词会误报「删掉了词」把 ⏎ 降成复制。

## 我试了什么

环境：LM Studio `qwen/qwen3-14b`（`gb_live_use_configured=true`），宿主 TextEdit，全程后台，没有用 `qa/front.sh`。同时至少有 wang、priya 两个实例共用模型。文字在 `/tmp/gbtest/marta-r8-*.txt`（加上一轮的 marta-2、marta-3），截图和状态在 `/tmp/gbqa/marta/r8/`。

| # | 文字 | 第一条标记 | 全部标完 | 标记数 |
|---|---|---|---|---|
| 1 | 西语 8 句：«…explicarnos na… habemos…»、英文 "We ain't got no water since monday"、对话破折号行 `—Aqui no a venido nadie`、`por que`、1.400（marta-r8-1） | 36 s | 44 s | 5（稍后重查再加 1） |
| 2 | 英文 7 句（marta-3，`have approved yesterday`） | 22 s | 27 s | 11 |
| 3 | 西语 7 句（marta-2，破折号开头、嵌套引号） | 15 s | 20 s | 6 |

三次都是前十几到三十几秒一条没有、然后几秒内全部出来，是共用模型在排队，不据此评速度。

**稿 1（引语 + por que + 键盘）**
- 初次标记：`estan → están`、`respondio → respondió`、`oposicion pidio mas → oposición pidió más`（三处合成一条）、`govierno → gobierno`、`todavia → todavía`。三处引语（«» 里的 na / habemos、英文 "…" 里的 ain't / monday、破折号行的 Aqui / a venido）**一条都没标**。`por que` 第一遍没查出来。
- `live:next; live:key=return; live:key=return`（不等）：两次都 `used=true`，只采用了 están，卡片停在 respondio。
- ⇥：跳到 oposicion…，respondio 的下划线留着。⌫：oposicion… 的下划线消失，卡片到 govierno。Esc：`used=true`，卡片关。⌃⌘J：续到 todavia（govierno 的下一条）。⏎ 采用 todavía，评审结束。
- 卡片关闭后第一句被重查，多出 **一条** `por que → porque`。点开采用，再连按 ⏎ 清完 respondio、govierno；最后一条之后紧跟的两下 ⏎ 都 `used=true`，等 1 秒后再按才是 `used=false`。
- 最终文字：`…con el ayuntamiento porque las obras…`、`respondió`、`gobierno`、`todavía`；三处引语和 1.400、14、Urrutikoetxea、The Guardian 原样；被我 ⌫ 掉的 `oposicion pidio mas` 没有再回来。

**稿 2（残留错误）**
- 采用 `have → has` 后按 Esc，约 10 秒后同一句出现新标记 `has → (delete)`，卡片是 `Zaragoza has approved (delete)`（`r8/hasdel-1.png`）。采用后成为 `approved yesterday a new budget`。之后没有第三条（语序还是不地道，但不再是语法错误）。
- 其余一路 ⏎，中间 ⇥⇥ 跳过 `promise → promised` 和 `works → work`；末尾多按的 ⏎ 和 ⇥ 被吃掉，再过 1 秒的 ⇥ 是 `used=false`。被跳过的两条下划线留着，没有绕回卡片。引语 "We ain't raising taxes" 没动，Neighbours 没动。

**稿 3（采用键换成 ⇥）**
- `set:gb_live_accept_key=tab` 后卡片底部一行变成「⇥ accept, next · → skip · ⌫ ignore · Esc close」（`r8/tabcard-1.png`）。
- `live:key=return` → `used=false`，卡片关闭。`live:key=tab` 采用 había，紧跟的第二下被吃掉。`live:key=right` 连跳两条。⇥ 采用 cortada，⌫ 忽略错误的 `el → (delete)`，末尾多按的 ⇥ 被吃掉。
- `" por que" → " porque"`（标记带前面的空格）采用后是 `llegar porque la carretera`，正确。
- 破折号开头的 `—Donde estaban ustedes…?` 和 «…se veia…» 没有标记。

**面板**（`simulate` JSON，TextEdit / accessibility / plain，文字 marta-r8-pol.txt）
- 润色，8 秒：11 处改动，其中 `na → nada`、`habemos → hay`、破折号行的 `a → ha` 三处 `accepted=false inQuote`，差异里是橙色引号角标，底部写「3 change(s) are inside a quotation and are not applied by default (click one to apply it)」，计数 8/11 accepted，⏎ = replace。`finalText` 里引语逐字是原话；英文引语模型自己就没动。`panel:toggle=1` 能把其中一处手动采用。
- 改错，约 25 秒：5 处改动，引语里的 2 处同样默认不采用。但 `checksSummary = words were deleted: empezar`，⏎ 降成 copy——我原文是「van a empezar a empezar」，删掉重复正是我要的。同时又漏了 `por que → porque`（润色里改了）。

**翻译**
- 西 → 英（和上一轮同一段 122 词）：系统约 7 秒，AI 约 20 秒，AI + 润色约 25 秒（都含排队）。
- 英 → 西（同上一轮 86 词）：系统 3 秒内，AI 16 秒，AI + 润色 6 秒。
- 数字专项（marta-r8-num.txt，51 词，1.400 millones / 2.350 / 12.500 / 18.30 / 3.200 / 1,4 billones）。

## 七个问题的回答

**1. 等多久。** 15–36 秒出第一条，全部标完再加 5–8 秒。和上一轮一样受共用模型影响。等待时菜单栏图标会变成省略号气泡（我只在代码里确认了 `AppDelegate.swift:73`，看不到画面）。

**2. 标得对不对。** 三段共 22 条建议：19 条对，2 条没必要（promise → promised、works → work，同上一轮），1 条错（`el → 删除`，同上一轮）。**引语里的建议这一轮是 0 条**。代价是引语里我自己的录入错误（`—Aqui`、`se veia`、`monday`）也不再提示了，这个取舍我接受，但希望能看得见（见 M8-06）。漏标：`por que` 第一遍没查出、采用别的之后重查才出现；`Que desastre!` 和缺 ¿ 的句子仍然不标。

**3. 键盘流程。** 比上一轮更稳，没有一下按键漏进文档。⇥ 跳过的留着下划线、不再绕回来，走到头就结束，这比上一轮的「悄悄绕回」好。⌫ 忽略很顺手，刚好用来处理 `el → 删除` 这种错的建议。两点小意见：Esc 之后 ⌃⌘J 续到的是「下一条」，我没决定的那一条被跳过了（下划线还在，但要自己点）；用 ⌫ 忽略后 `liveStatus` 的条数没有立刻减。

**4. 采用之后。** 文字都对，其余标记顺移。上一轮的两个保留意见都解决了：拆开的标记合并了；采用过的句子会重查（`has approved yesterday` → 再提示删 has；`por que` 也是靠重查补出来的）。重查要等卡片关闭后才出结果。

**5. 段落改写。** 现在敢按 ⏎：引语里的三处默认不放回，说明写得清楚。还剩的是编辑判断——两个 `dijo` 被换成 afirmó / explicó，我每次都要手动撤回。

**6. 翻译并润色。**

西 → 英，和上一轮逐句比：

| 原文要点 | 上一轮润色 | 这一轮润色 | 变化 |
|---|---|---|---|
| aprobó ayer el nuevo presupuesto | approved yesterday the new… | approved yesterday the new… | 没变 |
| la prioridad son las viviendas sociales | social housing is a priority | social housing is a priority | 没变（仍把「唯一优先」改成「之一」） |
| ¿Cuánto costará entonces…? | How much will then the housing plan cost? | How much then will the housing plan cost? | 仍不自然；系统的「…cost then?」更好 |
| 2.350.000 euros solo en el barrio | 2.35 million euros only in Las Fuentes neighborhood | 同左 | 没变（缺 the） |
| «Nos dijeron que "no pasaba nada"…» | 'nothing was wrong' | 同左 | 仍然比系统好 |
| —¿Y quién va a pagar…? —preguntó | —And who is going to pay…?— asked | —And who will pay for the delays?— asked | **没变：对话破折号仍留在英文里** |
| 1.400 millones | 1.4 billion | 1.4 billion | 对；这一次普通 AI 也译对了 |

英 → 西：普通 AI 这一轮把引号换成了 «»（上一轮没有），但「AI + 润色」又换回 " "，还把 periodistas 改成 reporteros。两者都还有「dijo la alcalde」「No estamos subiendo impuestos mientras soy alcaldesa」「han estado esperando durante 14 meses reparaciones」「no había nada mal」。系统翻译仍是三者里最像西语的（`mientras yo sea`、`aprobó el martes un nuevo presupuesto`），只错「alcalde」。

数字检查仍然有效，而且比我想的细：
- 系统翻译把 `1,4 billones de pesos` 译成 `1.4 billion pesos`（错，西语 billón 是 trillion），被标出 `numberMismatch: ['18.30', '1,4']`，⏎ 降成 copy。
- AI 译成 `1.4 trillion pesos`（对），不报 1,4。`1.400 millones → 1,400 million`、`2.350 → 2,350`、`12.500 → 12,500`、`3.200 → 3,200` 都没有误报。
- 误报一处：`a las 18.30 → at 6:30 pm` 被当成数字对不上（三种引擎都报），于是这段无论怎么译 ⏎ 都是 copy。

界面：语言栏右边固定有「System | AI | AI + polish」，当前引擎高亮，比上一轮好找得多。结果下面那行蓝色的「Translate and polish (AI, reads like a native writer)」还在，和分段控件重复。

**7. 整体。** 更像那个「只在确定时才开口、不碰别人的话」的校对了。会让我关掉它的事这一轮没有遇到。翻译我继续用系统翻译当初稿自己改，App 的价值在数字检查。

**关于采用键：我留在 ⏎。** ⇥ 那一套也能用、提示行也跟着变了，但 → 当跳过不直觉（→ 在我脑子里是移动光标），而且 ⏎ 在卡片开着时被交还给 TextEdit，会在光标处真的换一行——我连按惯了 ⏎ 的手一定会按出去。⏎ 现在有「评审中」状态和末尾 0.8 秒保护，我上一轮唯一的条件已经满足。⇥ 适合在聊天框里写东西的人（⏎ = 发送），应该留作选项。

## 模型的建议逐条评

稿 1：`estan → están` 对；`respondio → respondió` 对；`oposicion pidio mas → oposición pidió más` 对（三处合成一条，没法只采用其中一处，可以接受）；`govierno → gobierno` 对；`todavia → todavía` 对；`por que → porque` 对（重查时才出现）。

稿 2：`have → has` 对；重查后 `has → 删除` 对（合起来就是 approved yesterday）；`to → 删除` 对；`are → is` 对；`critisized → criticized` 对；`informations → information` 对；`promise → promised` 没必要；`works → work` 没必要；`on → in` 对；`is → are` 对；`wich → which` 对；`goverment → government` 对。

稿 3：`contesto → contestó` 对；`habia → había` 对；`mas → más` 对；`por que → porque` 对；`cortado → cortada` 对；`el → 删除` **错**（应为 él）。漏：`Que desastre!`。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| M8-01 | P1 | 翻译并润色 | 质量和上一轮基本一样。西 → 英：对话破折号原样留在英文里（`—And who will pay for the delays?— asked`）、`la prioridad` → `a priority`、`How much then will…`、`approved yesterday the new…`。英 → 西：`la alcalde`、`mientras soy alcaldesa`、`no había nada mal`；并且把普通 AI 已经换好的 «» 又换回 " "。 | 润色作为独立的第二步，只看译文、用目标语言的规范（英文 " " 包对话，西文 «»）；在面板里显示它相对普通译文改了什么。在做到之前，不要写「reads like a native writer」。 |
| M8-02 | P1 | 面板 · 改错 | 原文「van a empezar a empezar」，改错删掉重复的 `a empezar` → `checksSummary: words were deleted: empezar`，⏎ 降成 copy，提示「Checks failed」。同一段用润色不报。（`r8/fix.png`） | 被删的词在紧邻处还有同一个词（重复词）时不算「删掉了词」。 |
| M8-03 | P1 | 实时标记 | 倒问号 / 倒叹号仍然不标（`Que desastre!`），`el no sabía` 仍建议删掉 `el`。和上一轮 M7-05、M7-08 相同。 | 以 ? / ! 结尾而没有 ¿ / ¡ 的西语句子可以不靠模型直接标；重音区分词优先给加重音的方案。 |
| M8-04 | P2 | 数字检查 | `a las 18.30` → `at 6:30 pm` 被报「Numbers differ from the original: 18.30」，⏎ 降成 copy（系统、AI、AI + 润色都这样）。 | 「a las / at」后面的 H.MM 当作时间，接受 12 小时制的等价写法。 |
| M8-05 | P2 | 实时标记 | `por que` 第一遍没查出来，是我采用了同句的 `estan` 之后重查才出现；如果我没采用那一条，就不会有重查。改错面板对同一句也漏。 | 模型问题；可以考虑对有标记的句子在空闲时再查一次。 |
| M8-06 | P2 | 实时标记 | 引语里现在完全不提示，包括我自己的录入错误（`—Aqui`、`se veia`、`monday`），也没有任何迹象告诉我这一段被跳过了。 | 设置里给一个「引语里只提示拼写 / 重音」的选项；或在卡片计数旁写「引语未检查」。 |
| M8-07 | P2 | 卡片按键 | Esc（或采用键是 ⇥ 时按 ⏎）关掉卡片后再按 ⌃⌘J，续到的是下一条，刚才没决定的那一条被跳过（稿 3：contesto 没处理就到了 habia）。 | Esc 之后续到「同一条」；只有采用 / 跳过 / 忽略才前进。 |
| M8-08 | P2 | 润色 | `dijo → afirmó / explicó` 仍然默认采用。同 M7-09。 | 引述动词的替换默认不采用，或给「新闻」写作风格。 |
| M8-09 | P2 | 面板 · 润色 | 底部那行「3 change(s) are inside a quotation…」被底栏压住下半截（`r8/polish.png`）；改错里它下面的「words were deleted」也只露半行。文案「change(s)」。 | 提示行固定在底栏上方不滚动；单复数分开写。 |
| M8-10 | P2 | 翻译面板 | 分段控件之外，结果下面那行「Translate and polish…」链接还在；Side by side 里原文仍占掉半个面板。 | 去掉重复的链接；原文默认折叠成两行。 |
| M8-11 | P2 | 实时标记 | 标记文字带前导空格：`" por que" → " porque"`、`"has " → (delete)`；⌫ 忽略后 `liveStatus` 的条数不变（3 条标记时仍写 4）。 | 打磨。 |
| M8-12 | P2 | 测试接口 | `qa/gbqa.sh $Q 'live:off; quit'` 不返回（实例已退出，脚本一直等到超时）。 | quit 前先写 done。 |

## 上一轮问题的复查

| ID | 结果 | 依据 |
|---|---|---|
| M7-01 引语被改 | 改好了 | 实时标记三种引语 0 条建议；润色 3 处、改错 2 处 `accepted=false inQuote`，有角标和说明，`finalText` 保留原话 |
| M7-02 por que 拆成两条 | 改好了 | 两次都是一条 `por que → porque`，采用后 `ayuntamiento porque las obras`、`llegar porque la carretera` |
| M7-03 翻译并润色 | 没改好 | 逐句对比见第 6 问；只有入口（分段控件）改好了 |
| M7-04 末尾多按的 ⏎ | 改好了 | 最后一条后紧跟的两下 ⏎ `used=true`，1 秒后 `used=false`；采用键为 ⇥ 时同样 |
| M7-05 ¿ ¡ 漏标 | 没改好 | `Que desastre!` 仍不标（处理说明里是推后） |
| M7-06 采用后不重查 | 改好了 | `has approved yesterday` → 重查给出 `has → 删除` |
| M7-07 等待时没有状态 | 没法验证 | 代码里菜单栏图标会变（`AppDelegate.swift:73`），截不到；文本框旁边没有指示 |
| M7-08 el → 删除 | 没改好 | 同样的建议又出现了 |
| M7-09 dijo 被替换 | 没改好 | `dijo → afirmó`、`dijo → explicó` 默认采用 |
| M7-10 「翻译并润色」在折叠线下 | 改好了 | 语言栏右边固定三选一；原文占地方的问题还在（M8-10） |
| M7-11 引擎选择不一致 | 没法验证 | 这一轮每次都先出系统翻译，没复现 |
| M7-12 英 → 西引号 | 部分 | 普通 AI 换成了 «»；系统和 AI + 润色仍是 " " |
| M7-13 click: 卡死 | 改好了（靠说明） | 这一轮按说明只用 `panel:`，没有卡死；没有再试 `click:` |

合计 13 条：改好 6，部分 1，没改好 4，没法验证 2。

## 测不了的

- 真实的鼠标点击、真的在 TextEdit 里打字、下划线画得好不好看、卡片是否贴在词上方。
- `used=false` 的键在测试接口里不会真的送进 TextEdit，所以「采用键是 ⇥ 时 ⏎ 会换行」是按设计推断的。
- 菜单栏图标的变化（只读了代码）。
- 「只差大小写不采用」（`FLC → flc`）这一项我没有造句子试。
- 面板的 ⏎ 放回是 QA 模拟，没有真的写进 TextEdit。
- 速度：全程和别的实例共用模型，数字只能说明「排队时要等半分钟」。

备注：TextEdit 里留下了我这一轮开的 3 个 `/tmp/gbtest/host-21*.txt` 窗口（后台，没有手动保存）。实例已 `live:off` 并退出。
