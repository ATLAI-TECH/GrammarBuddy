# 王琳（植物学博士后，Word 写英文论文）— 用着顺不顺 Round 7

## 结论（评分 4/10；一句话：我会不会开着它写东西）

**现在不会开着它写。** 我最想要的那一半（Word 里实时标记 + ⌃⌘J → ⏎）在这次测试里一条标记都没出来：Word 在后台，新建了两个文档，前后等了约 10 分钟，状态一直是 `Waiting for Word to expose the document…`。所以实时标记、卡片、键盘采用、多页表现，我**一项都没能评**，下面相关的回答都写的是「测不了」，没有猜。

能评的另一半（面板里的润色、翻译并润色）质量很好：我埋的 12 处错全部改对，引用、基因名大小写、Col-0、单位、数字一个没动；「翻译并润色」的译文术语准确，可以直接放进论文。这部分单独打分是 8/10。

4 分 = 核心流程走不通（按 P0 记）+ 面板部分好用。如果 Word 在前台时实时标记是正常的，这个分数会高很多，但我没看到，不能替它打分。

## 我试了什么（宿主、文字、每一步和看到的结果，带时间）

宿主：Microsoft Word（后台，从未切到前台）。引擎：LM Studio / qwen/qwen3-14b，`gb_live_use_configured=true`。机器 M5 Pro 24 GB，同时有另外 4 个评审实例在跑。界面是英文（fresh 实例的默认）。

**测试文字 1**（`/tmp/gbtest/wang-1.txt`，7 句，方法 + 结果）：

> Seeds of Arabidopsis thaliana accession Col-0 and the flc-3 mutant **was** sterilized and stratified at 4 °C for 3 days before sowing [12]. Plants were grown under long-day **condition** (16 h light / 8 h dark) at 22 °C with a light intensity of 120 µmol m-2 s-1. Total RNA **were** extracted from rosette **leafs** using the RNeasy Plant Mini Kit (Qiagen) according to the **manufacturer** instructions. The expression of FLC was significantly **more higher** in Col-0 than in flc-3 (p < 0.01, n = 3), which is consistent with previous reports (Smith et al., 2020). Interestingly, the flc-3 plants flowered about 9 days earlier **then** the wild type, although their leaf number did not **differed**. **This results suggests** that FLC, but not FT, **are** required for the delay of flowering in non-vernalized plants. We therefore **choosed** FLC for further analysis, and its expression **were** normalised to ACT2 as described previously [7, 15].

埋了 12 处错（粗体）。不该动的：`[12]`、`[7, 15]`、`(Smith et al., 2020)`、`FLC` / `flc-3` / `FT` / `ACT2`、`Col-0`、`4 °C`、`120 µmol m-2 s-1`、`p < 0.01, n = 3`、`RNeasy Plant Mini Kit (Qiagen)`、英式拼写 `normalised`。

| 步骤 | 做了什么 | 结果 |
|---|---|---|
| 1 | `qa/host.sh word wang-1.txt` → Document12；4 秒后 `live:app=com.microsoft.Word; live:on`，每 2 秒 `dump`，共 61 秒 | 0 条标记。`liveStatus` 从第 2.8 秒起一直是 `Waiting for Word to expose the document…`，`liveValue` 为空 |
| 2 | 按说明 `open -g -b com.microsoft.Word` 重试，再看 40 秒 | 仍是 0 条，状态不变 |
| 3 | 只读探针 `axdoc:` / `axprobe:` | Word 的 `AXLayoutArea` 一直 `kids=0 nchars=0`（开关读回是 1，等到 +6 秒也没有子元素）；焦点在 `AXWindow` 上，没有文字接口 |
| 4 | 换一段文字：长文档 `wang-2.txt`（6 小节、1646 词、约 3–4 页，把段落重复并改了基因名 / 温度 / 引用，另加 6 句新的错句）→ Document13，看 42 秒 | 0 条，状态不变 |
| 5 | `live:off` → 重新 `live:app=` → `live:on`，等 30 秒；之后做面板测试期间又隔了几分钟，最后再等 15 秒 | 始终 0 条。总共约 10 分钟 |
| 6 | 没有标记时 `live:next`、`live:key=return` | `card: none`；`used=false`（没有卡片时 ⏎ 不被吃掉，这一点符合设计） |
| 7 | `qa/host.sh word-read` | Document12、Document13 的内容和我放进去的一致，没被改过 |
| 8 | 润色：`simulate:` JSON（via `word`，op `polish`），文字 1 的后 5 句（107 词） | 8 秒完成。11 处改动全部正确，检查通过，⏎ = 「write as tracked changes」。`panel:toggle=10` 能单独撤回一处；按 ⏎ 后日志 `word.trackedChange 11 changes`（QA 模拟，Word 没被碰） |
| 9 | 改错（op `fix`）整段文字 1 | 10 秒。13 处改动全部正确，但检查报 `words were deleted: more`，⏎ 被降级成「复制」 |
| 10 | 改错：一段全是记号的文字（`fri` / `flc` 小写等位基因、`[3-5]`、`1/2 MS`、`50 µM GA3`、`1% (w/v)`、`H3K27me3`、`vrn2-1`、`Fig. 2B`、`SALK_072590`、`LBb1.3`，只埋 1 处错，还放了正确的 `The data were`） | 8 秒。只改了埋的那 1 处（`were → was obtained`），其余一个字符没动，`data were` 没被「纠正」 |
| 11 | 翻译：中文论文段落 5 句（162 字，via `word`，op `translate`）→ 系统翻译 | 4 秒。术语错得很多，见下 |
| 12 | `panel:polishTranslate` | 12 秒。译文很好，见逐句核对。两次都报 `citation markers were added: (Smith et al., 2020)`（误报）。⏎ = 「insert below」 |

截图在 `docs/review/round-7/wang-shots/`（`w-polish-0.png`、`w-tr-sys-0.png`、`w-tr-polish-0.png` 等）。

结束时已 `live:off; quit`，只关了自己的实例。Word 里留下 Document12、Document13 两个未保存的新文档（按规则没有关闭）。

## 七个问题的回答

**1. 等多久。** 实时标记：61 秒 + 40 秒 + 42 秒 + 之后数分钟，一条都没有，所以「第一条几秒、全部几秒」没有数字。面板：润色 107 词 8 秒，改错 150 词 10 秒，系统翻译 4 秒，翻译并润色 12 秒。面板这几个时间我不觉得慢，论文是一段一段改的。

**2. 标得对不对。** 实时标记测不了。用面板「改错 / 润色」对同一段文字的结果代替（同一个模型，但不保证实时标记用的提示词和筛选一样）：12 处错全部找到并改对，没有把对的改错，引用、基因名大小写、Col-0、单位、数字都没碰。唯一不该改的是 `normalised → normalized`（见逐条评）。

**3. 键盘流程顺不顺。** 测不了，没有任何标记可以打开。只确认了一点：没有卡片时 `live:key=return` 返回 `used=false`，回车没有被抢走。

**⏎ 这个设计我同意吗**（只是读了说明后的意见，没用过）：有保留地同意。「卡片没开时 ⏎ 永远是换行」这条让我放心。我担心的是连按：⏎ ⏎ ⏎ 很快，而论文里有一类建议我必须每条都看清楚，就是碰到基因名、单位、数字的。`FLC → flc` 这种改动在卡片里只差大小写，连按时很容易漏过去，而意思完全相反（野生型基因 vs 突变体）。我希望：只差大小写、或者改动里含数字 / 单位 / 像基因名的词时，卡片停一下、要求按别的键（比如 ⌘⏎），或者干脆不给这种建议。

**4. 采用之后。** 测不了。

**5. 段落改写。** 改得好，而且保守：「润色」实际上只改了语法，没有重写句子，也没有换掉我的术语。对论文来说这是我想要的；但如果我选「润色」是想让句子更地道，这次的结果和「改错」没有区别，面板底部那句「Polish and tone rewrite whole sentences」也和实际不符。差异看得懂（红色删除线 + 绿色下划线，11/11 accepted）。敢按 ⏎，因为 Word 里是写成修订，我还能在 Word 里逐条拒绝。有一处不满意：`were normalised → was normalized` 合成了一条，我想要 `was` 但不想要 `normalized`，只能整条撤回再手改。

**6. 翻译并润色。** 准确、自然，数字、单位、基因名、引用全部保留。比系统翻译好得多，系统翻译那一版不能用。逐句核对：

| 中文 | 系统翻译 | 翻译并润色 | 评 |
|---|---|---|---|
| 长日照（16 h 光照 / 8 h 黑暗，22 °C）条件下 | under **long sunshine** (16 h light / 8 h darkness, 22 °C) | under long-day conditions (16 h light / 8 h dark, 22 °C) | 润色版对 |
| flc-3 的抽薹时间比 Col-0 平均提前约 9 天 | the **extraction time** of flc-3 was about 9 days earlier | the bolting time of flc-3 was approximately 9 days earlier on average than that of Col-0 | 润色版对；系统版把「抽薹」译成 extraction |
| 莲座叶数从 14.2 ± 1.1 片减少到 9.6 ± 0.8 片（n = 20，p < 0.01） | the number of **lotus leaves** decreased from 14.2 ± 1.1 to 9.6 ± 0.8 (n = 20, p < 0.01) | with the number of rosette leaves decreasing from 14.2 ± 1.1 to 9.6 ± 0.8 (n = 20, p < 0.01) | 润色版对，数字全在 |
| FLC 的转录水平仅为野生型的 5% 左右 | is only about 5% of that of the wild type | were about 5% of those in the wild type | 润色版丢了「仅」（only），意思没变，语气弱了一点 |
| FT 和 SOC1 的表达分别上调了 3.2 倍和 2.5 倍 [12, 15] | increased by 3.2 times and 2.5 times respectively [12, 15] | was upregulated 3.2-fold and 2.5-fold, respectively [12, 15] | 润色版是论文里的写法 |
| 与前人关于 FLC 直接抑制 FT 转录的报道一致（Smith et al., 2020） | consistent with the previous report that FLC directly inhibits FT transcription (Smith et al., 2020) | consistent with previous reports that FLC directly suppresses FT transcription (Smith et al., 2020) | 都可以；我会写 represses，但 suppresses 不算错 |
| 经过 6 周 4 °C 春化处理后…差异不再显著 | after 6 weeks of 4 °C vernalization treatment … is no longer significant | after a 6-week vernalization treatment at 4 °C … was no longer significant | 润色版时态统一成过去时，对 |
| flc-3 的早花表型依赖于未春化条件 | the early flowering **penotype** of flc-3 depends on **non-springification** conditions | the early-flowering phenotype of flc-3 depends on non-vernalized conditions | 系统版有拼写错误和生造词 |

**7. 整体。** 面板这一半像一个懂行的朋友：不乱动我的记号，改完写成修订让我自己过目。实时标记这一半我没见到。会让我关掉它的就是这次遇到的情况：打开 Word，什么都没有发生，也没有任何地方告诉我它在等什么、要等多久。和我现在用的工具比：Word 自带的拼写检查抓不到 `RNA were`、`This results suggests`、`then / than`，这个模型全抓到了；Grammarly 会去改我的基因名和单位，这里没有。只要实时标记在 Word 里稳定出现，我会换过来。

## 模型的建议逐条评（原词 → 新词：对 / 错 / 没必要）

来自面板「改错」（整段文字 1，13 处）；「润色」对后 5 句给出的 11 处与此完全一致。**不是实时标记的结果。**

| # | 原词 → 新词 | 评 |
|---|---|---|
| 0 | was → were（Col-0 and the flc-3 mutant … sterilized） | 对 |
| 1 | condition → conditions | 对 |
| 2 | were → was（Total RNA） | 对 |
| 3 | leafs → leaves | 对 |
| 4 | manufacturer → manufacturer's | 对 |
| 5 | 删除 more（more higher） | 对。但「改错」里触发了 `words were deleted: more`，⏎ 降级为复制 |
| 6 | then → than | 对 |
| 7 | differed → differ | 对 |
| 8 | This → These | 对 |
| 9 | suggests → suggest | 对 |
| 10 | are → is（FLC, but not FT, … required） | 对，主语判断正确 |
| 11 | choosed → chose | 对 |
| 12 | were normalised → was normalized | were → was 对；normalised → normalized 没必要（英式拼写不是错），而且两处并成了一条 |

第二段（记号密集）：`were → was`（SALK_072590 … obtained）对，其余 0 处改动，正确。`The data were` 没被改，正确。

没被建议修改的记号（全部正确保留）：`[12]`、`[7, 15]`、`[3-5]`、`(Smith et al., 2020)`、`FLC` / `flc-3` / `fri` / `flc` / `FT` / `ACT2` / `vrn2-1`、`Col-0`、`4 °C`、`120 µmol m-2 s-1`、`p < 0.01, n = 3`、`1/2 MS`、`50 µM GA3`、`1% (w/v)`、`H3K27me3`、`Fig. 2B`、`SALK_072590`、`LBb1.3`。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 |
|---|---|---|---|---|
| W7-01 | P0 | 实时标记 / Word | Word 在后台，`qa/host.sh word` 新建文档 → `live:app=com.microsoft.Word; live:on`。两个文档、`open -g -b` 重试、`live:off/on` 重试，约 10 分钟内 0 条标记，状态一直是 `Waiting for Word to expose the document…`。探针显示 `AXLayoutArea kids=0`，开关读回 1。Word 窗口当时被别的窗口完全盖住、从未成为前台。**我不能确定 Word 在前台时是否正常**，只能说在这个条件下完全不工作 | 查清楚是「Word 不在前台 / 窗口被遮住就不建树」还是别的原因；QA 说明里的后台测法对 Word 要先验证能用 |
| W7-02 | P1 | 实时标记 / 状态提示 | 上面这种情况下，等待没有上限，状态文字一直不变。我没看到这句话显示在哪里（截不到宿主画面），如果只在菜单栏里，写论文的人只会觉得「它没反应」 | 等超过 10–15 秒就明说「Word 没有提供文档内容」，并给出能做的事（点一下文档、改用选中后的按钮） |
| W7-03 | P1 | 面板 / 改错 / 检查 | 对整段文字 1 做「改错」：模型把 `more higher` 改成 `higher`（正确），检查报 `words were deleted: more`，⏎ 从「写为修订」降级成「复制」，整段 13 处正确的改动都不能一键放回。同样的改动在「润色」里检查通过。说明里写实时标记「只显示通过全部检查的结果」，如果用的是同一条检查，`more higher` 这类多余词在实时标记里可能永远标不出来（没能验证） | 删除一个紧邻的重复 / 冗余比较词（more + 比较级、the the）不算「丢词」；或者只把这一处标成需要确认，其余照常 ⏎ |
| W7-04 | P1 | 面板 / 翻译 / 检查 | 中文原文里引用用全角括号 `（Smith et al., 2020）`，译文是半角 `(Smith et al., 2020)`，检查报 `citation markers were added: (Smith et al., 2020)`，系统翻译和翻译并润色都报。引用其实原样保留了。中文稿里全角括号很常见，这个误报会每次都出现 | 比较引用之前先把全角括号、逗号、空格归一 |
| W7-05 | P2 | 面板 / 改错、润色 | `were normalised → was normalized`：把英式拼写改成美式，而且和语法改动并成一条，不能只要 `was`。同一段里我还写了 `sterilized`、`non-vernalized`，模型可能是在统一拼写，但没有告诉我 | 拼写体系的改动和语法改动分成两条；或者不动英式 / 美式拼写 |
| W7-06 | P2 | 面板 / 润色 | 「润色」对这段的输出和「改错」逐字相同，没有任何句子层面的改写；底部提示却写「Polish and tone rewrite whole sentences」 | 没有改写时不显示这句话；或者说明「这段只需要改语法」 |
| W7-07 | P2 | 面板 / 翻译 | 162 字的段落，系统翻译出来后，截图里看不到「翻译并润色」按钮（代码里它在译文下面，译文一长就在可见区域之外）。截图不能滚动，我不能确定真实面板里要不要滚 | 把「翻译并润色」放到底栏或语言选择那一行，始终可见 |
| W7-08 | P2 | 面板 / 翻译 / 系统翻译 | 系统翻译把论文术语译错：长日照 → long sunshine，抽薹 → extraction，莲座叶 → lotus leaves，未春化 → non-springification，还有拼写错误 penotype。它是翻译的默认第一步 | 来源是 Word、或者文字里有引用 / 单位时，默认直接用「翻译并润色」，或在系统翻译结果旁提示「专业术语建议用 AI」 |
| W7-09 | P2 | 翻译并润色 | 「仅为野生型的 5% 左右」译成 `about 5%`，丢了「仅」 | 提示词里强调保留限定词（only、at least、up to） |
| W7-10 | P2 | 键盘采用（设计意见，未实测） | ⏎ 连按时，只差大小写的建议（`FLC → flc`）在卡片上很难看出来，而意思相反 | 只差大小写、或涉及数字 / 单位 / 基因名样式的词时，不用 ⏎ 采用，或在卡片上醒目标出「仅大小写不同」 |

## 测不了的

- **Word 里的实时标记，全部**：第一条 / 全部标完的时间、标得对不对、坐标、卡片、⌃⌘J、⏎ / ⇥ / Esc / 继续打字、采用后文字是否真的改了、其余标记是否顺移、有没有越改越多。原因见 W7-01。
- **多页文档的表现**：长文档（Document13，约 3–4 页）放进去了，同样没有标记，所以换页、分页处的半句、第 2 页采用后改的位置对不对，都没看到。
- **Word 在前台时是否正常**：规则不允许把 App 切到前台，没有试。
- **真实写回 Word**：面板里的「写为修订」「插入到原文下方」都是 QA 模拟，Word 没被碰；修订在 Word 里长什么样、作者名是什么、带上下标（m⁻² s⁻¹）和斜体（*Arabidopsis thaliana*、基因名斜体）的文字写回后格式还在不在，都没验证。我的测试文字是纯文本，斜体和上标本来就没带进去，这对论文是很重要的一项。
- **带域的引用**（EndNote / Zotero 插入的 `[12]` 是域，不是普通文字）、脚注、表格、已有修订的文档。
- 真实的鼠标点击、选中后旁边的「改错 | 润色 | 翻译」按钮、下划线画得好不好看、「翻译并润色」按钮是否需要滚动才能看到。
- 速度是在 5 个评审实例共用一个 LM Studio 模型时测的，单独用应该更快。
