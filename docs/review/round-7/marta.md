# Marta（西英双语记者兼译者，偶尔法语）— 用着顺不顺 Round 7

## 结论（评分 6.5/10）

**写稿时我会开着实时标记；润色和「翻译并润色」我现在不敢按 ⏎。**
实时标记在西语、英语、法语里都干净利落：重音、性数一致、拼写基本全标对，数字（1.400、2.350.000、18.30、2,1 %）、人名（Larrañaga、Urrutikoetxea、Xoán Outeiro）、«…»、对话破折号一个都没被乱动，⌃⌘J → ⏎⏎⏎ 一路到底很顺。扣分在三处：模型会改**引语里被采访者的原话**且没有任何提示（记者的红线）；`por que → porque` 被拆成两条标记，只采用一条就把文字改坏；「翻译并润色」并不比系统翻译更像母语者，有两句反而更差。

## 我试了什么

环境：M5 Pro 24 GB，引擎 LM Studio `qwen/qwen3-14b`（`gb_live_use_configured=true`），宿主 TextEdit（后台，`live:app=com.apple.TextEdit`）。同时有 wang / priya / ines / sam 四个实例共用模型。测试文字在 `/tmp/gbtest/marta-1…5.txt`，截图和状态在 `/tmp/gbqa/marta/`。

| # | 文字 | 第一条标记 | 全部标完 | 标记数 |
|---|---|---|---|---|
| 1 | 西语新闻稿 8 句（marta-1） | **41 s** | 49 s | 9 |
| 2 | 西语 7 句，带对话破折号、嵌套引号、S.A.（marta-2） | 17 s | 24 s | 9 |
| 3 | 英文稿 7 句（marta-3） | 2 s | 7 s | 11 |
| 4 | 法语 5 句（marta-4） | 4 s | 5 s | 5 |
| 5 | 西语「几乎没错」的稿子，引语里有口语（marta-5） | 4 s | 7 s | 1 |

第 1 次的 41 秒里前 39 秒一条都没有（8 句一直在排队），超过了说明里的 40 秒线，但没重试就自己出来了；我判断是模型冷加载或别人在占用，不据此下速度结论。

**西语稿 1 的键盘流程**（每步后看 `state.json`）：
- `live:next` → 卡片 `aprobo → aprobó  1/9`，底部一行「⏎ accept and next · ⇥ skip · Esc close」（`es-card-1.png`）。
- ⏎ → 文字变成 aprobó，卡片自动换成 `defendio → defendió`；再 ⏎ → `tecnico → técnico`。
- ⇥ → 跳到 `nuevos → nuevas`，tecnico 留着没动；⏎ 采用。
- `live:key=a`（继续打字）→ `used=false`，卡片关闭，标记都还在。
- 再 `live:next` → 从光标后面的 `estan preocupado` 接着来；一路 ⏎，走到末尾后**绕回**到刚才跳过的 tecnico，采用后提示「All suggestions here are done」。
- 卡片关了以后再按 ⏎：`used=false`（交还给 TextEdit）。
- 最终 `liveValue`：9 处全部改对，1.400、«No vamos a subir…»、Inés Larrañaga、Las Fuentes 原样。**但 `Cuánto costará…?` 缺的 ¿ 始终没标**，此时再按 ⌃⌘J 得到「No suggestions here」。

**西语稿 2**：标出 `Donde → ¿Dónde`、contestó、había、veía（引语里的拼写，可以接受）、más、cortada；`por que` 被拆成 `" por" → (delete)` 和 `que → porque` 两条；`el → (delete)`（应为 él）；`Que desastre!` 没标。只采用 `que → porque` 那一条 → 文字变成「llegar **por porque** la carretera」，另一条删除标记还挂着，要再采用一次才对。全部采用后其余文字正确。

**英文稿 3**：⏎⏎ 后 ⇥⇥⇥ 连跳三条、空格（`used=false`，卡片关）、`live:next` 回到光标后的第一条、连按 9 次 ⏎ 清完。采用 `to → (delete)` 后同一行后面的标记 x 坐标从 644 变成 624，跟着移动了。引语里的 "We ain't raising taxes" 没被碰，Neighbours（英式拼写）没被改。

**润色**（`simulate` JSON，TextEdit / accessibility / plain）：
- 稿 A（引语是标准西语）：6–8 秒出结果，14 处改动，引语逐字保留，1.400 和 350 保留，⏎ = replace。
- 稿 B（引语是口语：«…explicarnos **na**… **habemos** muchos…»）：6 秒，10 处改动，其中两处在引语里：`na → nada`、`habemos → hay`。`checksSummary` 为空，⏎ 仍是 replace，只有一行灰字「Polish and tone rewrite whole sentences; please read before using.」（`polish2.png`）。同一段换成「改错」：3 处改动，`na → nada` 还是改了引语，同时漏了 `por que → porque`。`panel:toggle=1` 可以单独撤回这一处，撤回后 finalText 里是 na。

**翻译**（西 → 英，122 词）：系统翻译约 5 秒；`panel:polishTranslate` 9 秒。再反过来英 → 西（86 词）：AI 7 秒，系统翻译 6 秒内。逐句核对见下面第 6 问。

## 七个问题的回答

**1. 等多久。** 模型热的时候 2–4 秒出第一条、5–7 秒查完 5–8 句，这个速度我没意见，写完一段抬头就有了。但两次西语稿是 41/49 秒和 17/24 秒，期间屏幕上没有任何「正在查」的迹象（`liveStatus` 只在 dump 里看得到），我会以为它没开或者稿子没错。

**2. 标得对不对。** 五段共 35 条建议：30 条对，2 条没必要，3 条有问题（见逐条评）。不该碰的东西一个没碰：数字、人名地名、公司名 S.A.、The Guardian 的英文标题、«»、""、对话破折号、法语引号里的空格。漏标集中在**倒问号 / 倒叹号**（`Cuánto costará…?`、`Que desastre!`）——只有当第一个词本身也要改时（Donde → ¿Dónde）才带出来。另外句子需要调语序的（has approved yesterday a new budget）只改了一半。

**3. 键盘流程。** 顺。⏎ 采用并跳下一条、⇥ 跳过、走到头绕回被跳过的、Esc 关，都和我猜的一样；继续打字卡片自己让开，不吞键。计数「1/9」有用。**⏎ 这个设计我同意，但有一个条件**：见最后一条和 M7-04——卡片关闭后的那一下多余的 ⏎ 会进文档。我连按 ⏎ 清 9 条时，第 10 下就是 `used=false`。误采用我不太担心，因为卡片要我先按 ⌃⌘J 或点一下才出现，不会在我打字时突然抢走换行。

**4. 采用之后。** 文字真的改了，其余标记留着并且顺移，没有越改越多。两个保留意见：(a) 拆开的两条标记只采用一条会留下坏文字；(b) 一句话采用过一次后不再重查，所以残留的错（`has approved yesterday`、缺的 ¿）永远不会再被提示，而状态说「没有建议了」。

**5. 段落改写。** 改得像个不错的编辑：去掉重复的 presupuesto、`van a empezar → comenzarán`、`a subido → ha subido`。差异图看得懂，红删绿加，10/10 accepted，能逐处撤回。**但我不敢直接按 ⏎**：它把引语里的 na、habemos「纠正」了，还把四个 `dijo` 换成 afirmó / consideró / indicó / calificó——在新闻里 dijo 是故意中性的，「consideró」已经是在替说话人定性。标准西语的引语它一字没动，说明它不是有意保护引语，只是那次没发现可改的。

**6. 翻译并润色。**

西 → 英逐句（系统 / 翻译并润色）：

| 原文要点 | 系统翻译 | 翻译并润色 | 判断 |
|---|---|---|---|
| 1.400 millones de euros | 1.4 billion euros | 1.4 billion euros | 都对 |
| un 3,5 % más | 3.5% more | a 3.5% increase | 都对 |
| aprobó ayer el nuevo presupuesto | approved yesterday the new… | approved yesterday the new… | 都不自然，润色没修 |
| la prioridad son las viviendas sociales | the priority is social housing | social housing is **a** priority | 润色改了意思（唯一优先 → 之一） |
| «No vamos a subir…», dijo ante la prensa | "We are not going to raise taxes as long as I am mayor," she told the press. | 同样的引语 + she said before the press | 引号都换成 " "；系统更自然 |
| ¿Cuánto costará entonces…? | How much will the housing plan cost then? | How much will then the housing plan cost? | **润色更差，语序是错的** |
| 2.350.000 euros solo en el barrio | 2,350,000 euros only in the… | 2.35 million euros only in Las Fuentes neighborhood | 数字都对；润色丢了 the |
| «Nos dijeron que "no pasaba nada"…» | "They told us that "nothing was happening," …" | "They told us that 'nothing was wrong,' …" | 润色对（内层单引号、意思准）；系统双引号套双引号 |
| portavoz de los vecinos | spokesman for the neighbors | spokesperson for the residents | 润色更好 |
| —¿Y quién va a pagar…? —preguntó | "And who is going to pay for the delays?" asked… | —And who is going to pay for the delays?— asked… | **系统对；润色把西语的对话破折号原样留在英文里** |
| 人名、El Heraldo、Las Fuentes、31、350、14 | 全对 | 全对 | — |

对照：不带润色的普通 AI 翻译把 1.400 millones 写成了 **「1.400 million euros」**，App 发现了（`numberMismatch: ['1.400']`，⏎ 降级成 copy，理由「Numbers in the translation don't match the original」）。这个保护是我在整个产品里最信任的一处。

英 → 西：AI 第一次的结果和「翻译并润色」的结果**一字不差**，润色没有起任何作用。1.400 millones、3,5 %、2,35 millones de dólares、1.400 familias 都对。问题：引号留着 " " 没换成 «»；「dijo **la alcalde** Inés Larrañaga」（同一句引语里刚写了 alcaldesa）；「No estamos subiendo impuestos mientras soy alcaldesa」是字对字（应为 No vamos a subir… mientras yo sea）；「han estado esperando durante 14 meses reparaciones」语序不对；「no había nada mal」不是西语。系统翻译反而更好（「aprobó el martes un nuevo presupuesto」「mientras yo sea…」「1.400 familias」），只错了引语里的「alcalde」。

结论：数字和人名两边都没丢；「读起来像母语者写的」这句承诺目前不成立，我会用系统翻译当初稿自己改。

**7. 整体。** 实时标记像一个坐在旁边、只在确定时才开口的校对，这点比 LanguageTool 的西语检查安静，也比 Word 自带的准（它不会去改 Urrutikoetxea 或 1.400）。让我关掉它的只有一件事：发现它动了引语而我没注意到。润色和翻译目前是「看看可以，放回去不行」。

## 模型的建议逐条评

西语稿 1：`aprobo → aprobó` 对；`defendio → defendió` 对；`tecnico → técnico` 对；`nuevos → nuevas` 对；`estan preocupado → están preocupados` 对；`oposicion → oposición` 对；`pidio mas → pidió más` 对；`govierno → gobierno` 对；`todavia → todavía` 对。漏：`Cuánto → ¿Cuánto`。

西语稿 2：`Donde → ¿Dónde` 对；`contesto → contestó` 对；`habia → había` 对；`veia → veía` 对（引语内，仅拼写）；`mas → más` 对；`" por" → 删除` + `que → porque` 合起来对，拆成两条是错的；`cortado → cortada` 对；`el → 删除` **错**（应为 `el → él`，删掉主语不是我写的意思）。漏：`Que desastre! → ¡Qué desastre!`。

英文稿 3：`have → has` 对但不够（has approved yesterday 仍然是错的，应为 approved … yesterday）；`to → 删除`（told to reporters）对；`are → is` 对；`critisized → criticized` 对；`informations → information` 对；`promise → promised` 没必要 / 存疑（我要的是 promises）；`works → work` 没必要（工程意义的 works 是对的）；`on → in` 对；`is → are` 对；`wich → which` 对；`goverment → government` 对。

法语稿 4：`impots → impôts`、`habitant → habitants`、`inquiet → inquiets`、`coutera → coûtera`、`demander → demandé` 全对；`1,4 milliard`、« … » 没动。

西语稿 5：`nos creemos → se creen` **错**（在引语里，把说话人的「我们」改成「他们」，而且和前面的 Habemos 更不搭）。其余该留的全留了。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| M7-01 | P0 | 润色 / 改错 / 实时标记 | 引语里的原话被改且没有任何提示。润色稿 B：`«…explicarnos na… habemos muchos…»` → `nada`、`hay`，⏎ 仍是 replace；改错同一段也改 `na → nada`；实时标记 marta-5 建议 `nos creemos → se creen`（在 «» 内）。 | 把 «…»、"…"、“…”、对话破折号后的直接引语当保护内容：默认不改；确实要提的只提拼写 / 重音，并在卡片和差异里标「在引语内」，润色时这些改动默认不采用。 |
| M7-02 | P0 | 实时标记 | 一处修改拆成两条标记：`por que → porque` 变成 `" por" → (delete)` 和 `que → porque`。只采用第二条（`live:accept=6`）→ 文字成了「llegar por porque la carretera」。 | 相邻（中间只隔空格）的改动合并成一条 `por que → porque`。 |
| M7-03 | P1 | 翻译并润色 | 不比系统翻译好，局部更差：西 → 英「How much will then the housing plan cost?」、对话破折号原样留在英文里、`la prioridad` → `a priority`；英 → 西润色结果和普通 AI 翻译一字不差，「la alcalde」「mientras soy alcaldesa」「no había nada mal」。 | 润色单独做第二步（先译、再以目标语言润色），提示词里写明目标语言的引号和对话标点习惯（英 " "、西 «» 或按用户设置）；面板里给出相对系统翻译的差异。 |
| M7-04 | P1 | 卡片按键 | 连按 ⏎ 清完最后一条后卡片关闭，多按的一下 `used=false`，会作为换行进入文档（位置在最后一次替换处，多半在句子中间）。 | 最后一条采用后 0.5–1 秒内吞掉紧跟的 ⏎，或者让「All suggestions here are done」那个提示接住一次 ⏎。 |
| M7-05 | P1 | 实时标记 | 倒问号 / 倒叹号漏标：`Cuánto costará…?`、`Que desastre!` 都不标，随后 ⌃⌘J 说「No suggestions here」。 | 西语句子以 ? / ! 结尾而没有 ¿ / ¡ 时可以不靠模型直接标；检查「只加标点」的改动是不是被过滤掉了。 |
| M7-06 | P1 | 实时标记 | 采用过一次的句子不再重查，残留错误（`has approved yesterday`）之后永远没有提示。 | 这句的标记全部处理完之后，后台再查一遍，只显示新的、且不与刚采用的改动重叠的建议。 |
| M7-07 | P2 | 实时标记 | 等待期间没有任何可见状态。第一次 41 秒才出第一条，我会以为没开。 | 菜单栏图标或文本框角落给一个「正在查 3/8」的小指示。 |
| M7-08 | P2 | 实时标记 | `dijo que el no sabía nada`：建议删掉 `el`，正确的是 `él`。 | 重音区分词（el/él、mas/más、por que/porque）优先给加重音的方案。 |
| M7-09 | P2 | 润色 | 四个 `dijo` 被换成 afirmó / consideró / indicó / calificó。新闻稿里引述动词是编辑判断。 | 引述动词的替换默认不采用，或者在「写作」设置里给一个「新闻 / 保留 dijo」的选项。 |
| M7-10 | P2 | 翻译面板 | 122 词的原文在 Side by side 里占满了面板，译文只露出三行，「翻译并润色」的链接在折叠线以下（`tr1-sys.png`）；润色后的面板和系统翻译的面板除了右上角引擎名看不出区别（`tr1-ai.png`）。 | 原文默认折叠；「翻译并润色」放到底栏。 |
| M7-11 | P2 | 翻译 | 重启实例后第一次英 → 西直接用了 AI（标记是 LM Studio），没有说明；紧接着同样的操作用的是系统翻译。 | 引擎选择保持一致，回退到 AI 时写一句原因。 |
| M7-12 | P2 | 英 → 西翻译 | 英文 " " 没有换成 «»（系统和 AI 都是）。西 → 英方向是换了的。 | 按目标语言的习惯换引号，或在语言设置里让我选 «» / “”。 |
| M7-13 | P2 | 测试接口 | `click:421,362`（点 Translation 分段控件）让实例卡死，之后所有命令超时，只能 pkill 重启。说明里只警告了弹出菜单。 | 说明里补一句；或给 `panel:view=translation`。 |

## 测不了的

- 真实的鼠标点下划线、真的在 TextEdit 里打字、下划线画得好不好看、卡片是否真的贴在词的上方（只有坐标：每条标记高 13、宽度与词长相符，下划线层在窗口顺序里紧贴我的 TextEdit 窗口）。
- M7-04 的后果：测试接口里 `used=false` 的键不会真的送进 TextEdit，所以「多出一个换行」是按设计推断的，没有亲眼看到。
- 采用 `que → porque` 后 `el` 那条标记从 880 处 19 宽变成 900 处 13 宽，像是换行后位置有变；看不到画面，不能确定下划线还压在 `el` 上。
- 面板里的 ⏎ 放回是「QA simulation」，没有真的写进 TextEdit。
- 「忽略 / 这句都忽略」没有测试命令，没测。
- 速度受另外四个实例影响，41 秒那次不能算数。

备注：开始时我用 `osascript` 读了一次 TextEdit 的文档名（只读，没有 activate），AppleEvent 超时，之后没再用。TextEdit 里留下了我开的 5 个 `/tmp/gbtest/host-*.txt` 窗口（在后台，没有手动保存），实例已 `live:off` 并退出。
