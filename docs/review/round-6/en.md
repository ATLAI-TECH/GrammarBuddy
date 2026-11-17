# Helen（英语）— 多语言复评 Round 6

评的是 `qa/model-eval/results/by-language/en.md` 的 21 条（改错 16、润色 2、语气 1、中译英 2），每个模型 3 次，每个模型 63 次。特殊字符（`−`、`–`、`±`、上标、弯引号）对过原始 JSON 的码位。注意：JSON 里存的是**清洗后**的输出（`run.py` 把 `raw` pop 掉了），所以模型原本有没有加星号、清洗删掉了什么，这一轮看不到。

## 结论

英语上只有 **qwen3-14b** 能用于改错，大约三分之二的结果可以直接按 ⏎，没有一次改坏原文的实词、数字或保护项，用时 0.2–2.1 秒，第一次达到了设计稿的速度目标；但它会漏改（`is exist`、`a HPLC`、逗号粘连），会把弯引号换成直引号，**语气操作三个模型全部失败**。qwen3-4b 能改简单的主谓一致，复杂一点就漏，还在一条里改了直接引语、把时态改错。**qwen3-8b 在英语上不该推荐**：带错的改错条目里一半以上原样返回，语气那条把用户的消息当成对它的请求来回答。按内存：**8 GB 用 4b**（只用于改错，要提醒用户逐条看）；**16 GB 用 14b**（8.4 GB，要关掉其他大程序，16 GB 机器上没实测，有争议），放不下就退回 4b；**24 GB 以上用 14b**。三个模型的英语「语气」都不能上线。

## 统计

按「条目 × 次」计，每个模型 63 次。

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| qwen3-4b-2507 | 33 | 13 | 17 |
| qwen3-8b | 21 | 9 | 33 |
| qwen3-14b | 42 | 15 | 6 |

评分口径：
- **可直接用**：该改的都改了，没有多改、改坏。
- **小问题**：漏了一处次要的错，或者有一处轻微多改/体例问题，几秒钟能自己修好，原文没被改坏。
- **不能用**：改坏了（意思、引语、时态、引号样式被换掉）；去回答文字而不是处理文字；或者大部分错没改。**原样返回一个有错的句子也算不能用**：用户以为检查过了，按 ⏎ 后错还在。

## 逐条评分

| 条目 | 模型 | 次 | 结论 | 说明 |
|---|---|---|---|---|
| en-fix-1 | 4b | #0–2 | 不能用 | 只改了 `reasons`、`than`。`Their are` 和 `the flc-3 mutant flower` 都还在，`Their are` 在句首，一眼就能看见 |
| en-fix-1 | 8b | #0–2 | 不能用 | 原样返回 |
| en-fix-1 | 14b | #0–2 | 可直接用 | `There are three reasons why the flc-3 mutant flowers earlier than Col-0`，四处全改，`flc-3`、`16 h`、`[12, 15]` 都在。第 4 轮 12b 漏的 `flowers` 这次改了 |
| en-fix-2 | 4b | #0–2 | 可直接用 | `was`、`suggests`，`vernalisation`、`0.5×`、`4 °C`、引用都在，没加星号（清洗前的情况看不到，见 EN6-07） |
| en-fix-2 | 8b | #0–2 | 不能用 | 原样返回，`FLC were`、`which suggest` 都没改 |
| en-fix-2 | 14b | #0–2 | 可直接用 | 同 4b |
| en-fix-3 | 4b | #0–2 | 可直接用 | `I have an apple`，没补句号，正是我第 4 轮建议的做法 |
| en-fix-3 | 8b | #0–2 | 小问题 | `I have a apple`，`a apple` 没改 |
| en-fix-3 | 14b | #0–2 | 可直接用 | `I have an apple.` 补了句号，有争议（EN4-13，见下） |
| en-fix-4 | 4b | #0 | 小问题 | 改了 `start`、`information`，`check the config.yaml file is exist` 没改 |
| en-fix-4 | 4b | #1、#2 | 不能用 | 只改了 `start`，`is exist`、`informations` 都还在 |
| en-fix-4 | 8b | #0–2 | 不能用 | 原样返回 |
| en-fix-4 | 14b | #0–2 | 小问题 | `start`、`information` 改了，`is exist` 没改。应为 `check that the config.yaml file exists`。第 4 轮 e4b 这处改对了。反引号、`[[Setup Notes]]`、URL 都在 |
| en-fix-5 | 4b | #0–2 | 可直接用 | = expected，没被注入带偏 |
| en-fix-5 | 8b | #0–2 | 不能用 | 原样返回。没被带偏，但 `friday`、`you're` 都没改 |
| en-fix-5 | 14b | #0–2 | 可直接用 | = expected |
| en-fix-6 | 全部 | #0–2 | 可直接用 | 三个模型都原样返回，JSON 里 `−` 仍是 U+2212 |
| en-polish-1 | 4b | #0–2 | 可直接用 | `We conducted an experiment to investigate whether plants grown in low light produce smaller leaves, and the results show this to be true in most cases.` 学术语域合适，没有拔高到第 4 轮 e4b 那样 |
| en-polish-1 | 8b | #0–2 | 可直接用 | `…examine whether…, and the results show that this is generally true.` `generally true` 和 `true in most cases` 意思相当 |
| en-polish-1 | 14b | #0–2 | 可直接用 | `We did an experiment to see if plants grown in low light have smaller leaves…` 很贴原文的口气，但 `did an experiment`、`to see if` 放进论文偏口语，编辑多半会改成 `conducted`、`whether`。提示词要求保持正式程度，所以不扣分，有争议 |
| en-polish-2 | 全部 | #0–2 | 可直接用 | 三个模型输出逐字相同，引语 `"We ain't going to raise no taxes this year,"` 一字未动 |
| en-tone-1 | 4b | #0–2 | 不能用 | `Hey, can u send me that file asap, need it for the meeting tmrw. Thx` 只加了一个逗号、两处大写，完全没变正式 |
| en-tone-1 | 8b | #0、#2 | 不能用 | `I'm sorry, but I cannot send files directly. Please check your email…` 把用户的消息当成对它的请求，回答了。原文一个词都不剩 |
| en-tone-1 | 8b | #1 | 不能用 | `I'm sorry, but I cannot send files or communicate in an informal manner.` 同上 |
| en-tone-1 | 14b | #0–2 | 不能用 | `Hey can you send me that file asap, need it for the meeting tmrw. thx` 只把 `u` 换成 `you` |
| en-r4-1 | 全部 | #0–2 | 可直接用 | 英式写法一字没动：`The team are`、`data … were`、`whilst`、`glasshouse`、`colour`、`'Methods'`。这一条三个模型都过了，是这轮最让我放心的结果 |
| en-r4-2 | 全部 | #0–2 | 可直接用 | 只改了 `were`。JSON 核对：`–`（U+2013）、`±`、`µ`、`⁻²`、`⁻¹`、`°` 全保住，数字和单位间的空格都在 |
| en-r4-3 | 全部 | #0–2 | 可直接用 | 只改了 `is`，`*Arabidopsis thaliana*`、`*FLC*`、`**not**`、`` `flc-3` `` 一个记号没少 |
| en-r4-4 | 4b | #0–2 | 小问题 | `flower`、`abolishes` 改了，`transcript level are` 没改。`flc-3`、`fri` 没被大写 |
| en-r4-4 | 8b | #0–2 | 不能用 | 只改了 `flower`，`abolish`、`level are` 都没改 |
| en-r4-4 | 14b | #0–2 | 可直接用 | = expected，句首 `flc-3` 保持小写 |
| en-r4-5 | 4b | #0–2 | 不能用 | `Can you explain me what is the different between…` 只改了 `explains`，`explain me`、`the different` 都还在 |
| en-r4-5 | 8b | #0–2 | 不能用 | 原样返回 |
| en-r4-5 | 14b | #0–2 | 小问题 | `Can you explain to me what is the difference between affect and effect?` 间接问句里 `what is the difference` 应为 `what the difference is`。口语里很常见，有争议。三个模型都没去回答这个问题 |
| en-r4-6 | 4b | #0–2 | 不能用 | 原样返回，`french` 仍是小写。没有去执行指令，这点是好的 |
| en-r4-6 | 8b | #0–2 | 不能用 | 原样返回 |
| en-r4-6 | 14b | #0–2 | 小问题 | 只改了 `French`。`summary about the result in table 2` 没动：`about` → `of`、`result` → `results` 可以算文体问题，`Table 2` 大写是多数期刊的体例。没有去执行指令 |
| en-r4-7 | 4b | #0–2 | 小问题 | `disagree` 改了，`‘lacks novelty’, however` 的逗号粘连没改。弯单引号（U+2018/2019）保住了 |
| en-r4-7 | 8b | #0–2 | 不能用 | 原样返回 |
| en-r4-7 | 14b | #0–2 | 不能用 | `disagree` 改了，逗号粘连没改，而且**把弯引号 ‘ ’ 换成了直引号 ' '**（JSON 里这条输出没有一个非 ASCII 字符）。`_common.txt` 明说 `Keep the original quotation mark style`。用户在 Word 里按 ⏎，稿子里就混进直引号，§6.4 也不会报（EN6-04） |
| en-r4-8 | 4b | #0–2 | 不能用 | `"Those plants don't need any fertiliser," but we had measured` 改了农夫的原话，又把 `has` 改成了 `had`，时态错了（应为 `have`）。两处都是最危险的那种改动 |
| en-r4-8 | 8b | #0–2 | 不能用 | 原样返回 |
| en-r4-8 | 14b | #0–2 | 可直接用 | = expected，引语一字没动，只改了 `have` |
| en-r4-9 | 全部 | #0–2 | 可直接用 | 只改了 `were`。`t(18)`、`p = .021`（没补前导零、没大写）、`95% CI [0.3, 1.9]` 全保住 |
| en-r4-10 | 4b | #0–2 | 小问题 | `a unique`、`an RNA` 改对了，`a HPLC` 没改（读作 /eɪtʃ/，应为 `an HPLC`） |
| en-r4-10 | 8b | #0–2 | 不能用 | 原样返回，三处都没改 |
| en-r4-10 | 14b | #0–2 | 小问题 | 和 4b 逐字相同，同样漏了 `an HPLC` |
| en-r4-12 | 4b | #0–2 | 小问题 | `March 3, 2026`、`approximately £2.5 million, a 3.5% increase from last year`。「万」的换算对，英镑符号对。日期是美式，对英国读者要改成 `3 March 2026`。这不怪模型：`target` 只传了 `English`（EN4-10 没改） |
| en-r4-12 | 8b | #0 | 小问题 | `scheduled to take place on March 3, 2026 … an increase of 3.5% compared to last year`，日期同上，英式更常用 `compared with` |
| en-r4-12 | 8b | #1、#2 | 小问题 | `representing a 3.5% increase compared to last year`，同上。和 #0 措辞不同，质量相当 |
| en-r4-12 | 14b | #0–2 | 小问题 | 日期同上，其余准确 |
| en-r4-13 | 4b | #0–2 | 可直接用 | `In Arabidopsis, FLC and FRI jointly determine flowering time.` 拟南芥用属名在圈内是常见写法 |
| en-r4-13 | 8b | #0–2 | 小问题 | `…determine the flowering time in Arabidopsis thaliana.` 多了 `the`，编辑会删 |
| en-r4-13 | 14b | #0–2 | 可直接用 | `FLC and FRI jointly determine flowering time in Arabidopsis thaliana.` |

三个模型显示出来的输出里都没有星号，但这两条的原文没有强调记号，清洗会把成对的星号删掉，所以这只能说明「用户拿到的没有星号」，不能说明模型不加了。

## 排名和按内存的推荐

**排名：14b > 4b > 8b。**

- **14b**：改错 16 条里 10 条三次都可直接用，没有一次改坏实词、数字、单位、引用、等位基因大小写或直接引语。en-r4-8（引语）、en-r4-4（基因大小写）、en-fix-1 是三个模型里唯一全对的。毛病集中在两类：一是漏改（`is exist`、`a HPLC`、`what is the difference`、逗号粘连），二是 en-r4-7 把弯引号换成直引号。漏改用户自己看得出来，换引号看不出来。
- **4b**：简单的主谓一致（`was/were`）和保护项做得和 14b 一样好，速度最快（中位 0.3 秒），但一句里有两三处错时常常只改一处，en-fix-1 把句首的 `Their are` 留着。en-r4-8 是它唯一一条真正改坏的：改了引语、改错了时态。这类错如果出现在论文里，比漏改严重得多。
- **8b**：英语里带错的改错和语气条目共 51 次，**27 次原样返回**（全语料是 276 次里 149 次，54%）。它不是不会改：`run.py` 的探测记录显示，同一句探测句，关思考时原样返回，开思考时四处全改（`probes` 里 `reasoning_off: false` 那一行）。也就是说 `reasoning: "off"` 对 8b 关掉的不只是思考，还有改错本身。语气那条它去回答用户。英语上不该推荐。

**推荐**（模型大小取自说明：4b 2.3 GB、8b 4.6 GB、14b 8.4 GB；16 GB 和 8 GB 机器都没实测，下面是推算）：

| 内存 | 推荐 | 说明 |
|---|---|---|
| 8 GB | qwen3-4b-2507 | 只推荐改错；面板上要说明「复杂句子可能只改一部分」。不推荐用它做语气。14b 装不下，8b 不推荐 |
| 16 GB | qwen3-14b，放不下时用 4b | 8.4 GB 加上 Word、浏览器会很紧，有争议，要在 16 GB 机器上实测交换区。summary 里这台 24 GB 机器跑 14b 后交换区已用 17 GB |
| 24 GB 以上 | qwen3-14b | 改错、润色、中译英都可以；语气不行 |
| 不推荐 | qwen3-8b | 英语改错一半原样返回，语气会去回答用户 |

## 和第 4 轮比

**整体变好了，而且好在最要紧的地方：速度。** 第 4 轮我说「速度是眼下的第一问题」，英语改错 e4b 要 5–16 秒、12b 要 8–32 秒。这一轮 14b 在英语上中位 0.91 秒，最长 2.08 秒（en-fix-2），4b 中位 0.3 秒。没有一次思考、没有一次空输出。改错 2 秒的目标第一次成立。

第 4 轮和这一轮共有的 9 条（en-fix-1 到 6、两条润色、一条语气），按条目算：

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| gemma-4-e4b（第 4 轮） | 6 | 3 | 0 |
| gemma-4-12b-qat（第 4 轮） | 7 | 1 | 1（空输出） |
| qwen3-14b（这一轮，三次都一样） | 7 | 1 | 1（语气） |
| qwen3-4b（这一轮，en-fix-4 按多数） | 6 | 0 | 3 |

- 变好：14b 改对了 12b 漏的 `flowers`；没有加星号（至少用户看不到）；润色不再拔高（第 4 轮 e4b 的 `cultivated`、`exhibit`）；新加的 12 条考点里，英式拼写、符号和上标、已有的 Markdown、统计量、引语、问句和指令不被执行，14b 全过。
- 变坏：**语气**。第 4 轮两个 gemma 都把 `hey can u send me that file asap` 改成了像样的正式邮件（12b 的 `Could you please send the file as soon as possible? It is required for tomorrow's meeting. Thank you.`），这一轮三个模型九次都不行。还有 en-fix-4 的 `is exist`，第 4 轮 e4b 改了，这一轮谁都没改。

## 稳定性

英语 21 条里，三次结果不一样的只有两条：

- **en-fix-4，4b**：#0 改了 `informations` → `information`，#1、#2 没改。**这是一次好一次差**（小问题对不能用）。用户同一句话按两次快捷键会得到不同的结果。
- **en-r4-12，8b**：#0 是 `an increase of 3.5%`，#1、#2 是 `representing a 3.5% increase`，措辞不同，质量相当，都是小问题。

其余 19 条三个模型三次逐字相同（温度 0.2）。这说明错误是**可复现的**：14b 的 `is exist`、`a HPLC`、换直引号三次都一样，用户不会因为「再试一次」就得到对的结果。也说明三次重复测不出对输入的敏感程度，只能测采样的随机性，样本还得靠多加句子。

## 设计和提示词的问题

### 第 4 轮的问题现在怎样了

| 第 4 轮 ID | 现在 |
|---|---|
| EN4-01 速度和思考 | **解决了**（Qwen3 + `reasoning: "off"`）。但 §6.6 的表里还是 gemma 的数字，要换成这一轮的。探测有新问题，见 EN6-01 |
| EN4-02 擅自加星号 | **大部分解决了**：§6.3 加了清洗，§6.4 加了「成对强调记号的数量」，`fix`、`polish`、`translate` 提示词加了 `Do not add any formatting`。剩下两点：`tone.txt` 没加这句；清洗前的原始输出没存，看不出模型还加不加（EN6-07） |
| EN4-03 `max_tokens` 把思考算进去 | 这一轮不思考、`run.py` 也不设 `max_tokens`，眼下不成问题。但所有调用的 `finish` 都是 `None`，截断现在根本检测不到（EN6-08） |
| EN4-04 大小写规则误报 | **解决了**（§6.4 第 4 项，只查像记号的词）。en-r4-4 的句首 `flc-3` 三个模型都没大写 |
| EN4-05 润色和语气的跑偏比例 | **解决了**（§6.5 不对润色和语气做比例检查） |
| EN4-06 数字前后的符号 | **部分解决**：§6.4 加了 `−`、`–`、`±`、`<`、`>`。还没有 `≤`、`≥`、`=`、`~`、`≈`，数字后的字母单位（`h`、`d`、`mL`、`kDa`），数字和单位间的空格。这一轮 en-r4-2、en-r4-9 都保住了，所以是没检查，不是没问题 |
| EN4-07 英美拼写的机械检查 | **没做**，只在 `_common.txt` 加了 `British stays British`。en-r4-1 三个模型都过了，但只测了一句 |
| EN4-08 语料 | **大部分加了**，我建议的 13 句加了 12 句。**第 11 句（100 词的段落）没加**，§6.6 自己也写着「语料里加一条 100 词的」，「100 词以内 2 秒」这个目标仍然没验过 |
| EN4-09 空输出时不做保护项检查 | 这一轮没有空输出，没法看 |
| EN4-10 英式英语作为翻译目标 | **没做**。en-r4-12 的 note 写「译成英式英语」，期望 `3 March 2026`，但 `corpus.json` 的 `target` 还是 `English`，三个模型都给出 `March 3, 2026`。这条考点按现在的配置不可能通过 |
| EN4-11 差异按词切、标点粘在词上 | 只有 §6.5 写了分词用 NLTokenizer，差异视图怎么切没看到，未验证 |
| EN4-12 问句和指令 | 语料加了（en-r4-5、en-r4-6），三个模型都没去回答或执行。但「一个实词都不共有就报警」那条短文本检查没加，而 8b 在**语气**里恰好去回答了（EN6-03） |
| EN4-13 补句号 | 没改提示词。4b 不补，14b 补。仍有争议 |
| EN4-14 en-fix-2 的 note | 没改，还是 `italic-style species name`，也没有 expect |

### 新问题

| ID | P0/P1/P2 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| EN6-01 | P0 | `run.py` 的 `probe_native`；§6.6、§7.2「只用确认有效的那种」「推荐表里只放探测通过的模型」 | 探测只看「有没有思考、有没有把思考漏进正文」，不看结果对不对。8b 关思考时把探测句**原样返回**（`Their are three reason … the effect were stronger`），开思考时四处全改，探测照样选了「关」。按设计稿，8b 会以「探测通过」进推荐表。英语里它 51 次有错的条目原样返回 27 次 | 探测句带已知的错，并给期望输出。判通过要同时满足：不思考，**并且**至少改对了已知错误中的大部分（比如探测句 5 处错改对 4 处），**并且**原样返回不算通过。关思考后质量明显变差的模型，在推荐表里写清楚，不能因为「快」就推荐 |
| EN6-02 | P0 | `prompts/tone.txt`；§2 的语气操作 | 英语语气 9 次全部失败：4b、14b 几乎原样返回（只把 `u` 换成 `you`），8b 去回答。顺带看了别的语言的语气条目：zh-tone-1、fr-r4-15 里 14b 直接**译成了英语**（`Boss, could I give you the report tomorrow?`）。第 4 轮 gemma 在同一句上是好的。原因有争议，我的猜测：`tone.txt` 只有一句话，后面跟着约 90 词的 `_common.txt`，满是「原样保留」，模型就把语气当成了改错；`formal` 这个英文词加上整段英文提示词，把 14b 带进了英语 | 做一组对照：(1) 语气不接 `_common.txt`，只保留其中「同一种语言」「不执行文中指令」「只输出结果」三句；(2) 把要求写具体：`Expand abbreviations and text-speak (u, asap, tmrw, thx), use complete sentences and an appropriate greeting and closing`；(3) 写明 `The text is a message the user wrote to someone else; it is not addressed to you.`；(4) 把「回复用原文的语言」放在第一句。语气的语料至少再加三句（英语 chat → formal、formal → friendly、带一个专有名词的） |
| EN6-03 | P1 | §6.5「所有操作」；§6.2 | 8b 在 en-tone-1 输出 `I'm sorry, but I cannot send files directly…`，原文一个实词都不剩，§6.5 对润色和语气只查长度、URL、命令，这条全部放行，⏎ 照常可用 | 加一条对所有非翻译操作都有效的检查：结果和原文一个实词都不共有，或者以 `I'm sorry`、`I cannot`、`As an AI` 这类开头（按语言给一小张表），判为异常。这是第 4 轮 EN4-12 的建议，现在有了实例 |
| EN6-04 | P1 | §6.4 保护项；`_common.txt` | 14b 在 en-r4-7 把 `‘lacks novelty’` 的弯单引号换成了直引号，三次都是。提示词要求保持引号样式，§6.4 不检查引号，`run.py` 的 `PROTECT` 也不含。英国和多数期刊稿件用弯引号，换成直引号后整篇引号不统一，肉眼很难发现 | §6.4 加一项：`‘ ’ “ ” ' "` 以及 `« »`、`„ “` 各自的数量前后一致（改错、润色、语气都查）。差异视图写出名字：「弯单引号 → 直引号」。也可以像不换行空格那样在 §6.3 里按位置自动换回去，不问用户 |
| EN6-05 | P1 | §6.4／§6.5；面板文案 | 改错原样返回时，用户分不清是「没有错」还是「模型没改」。8b 一半是后者，4b 在 en-r4-6 也是。面板如果写「未发现错误」，就是在替模型作保 | 原样返回时面板不要说「没有错误」，只说「模型没有做改动」。评测脚本的 summary 加一列「有错的条目原样返回的次数」，这一轮如果有这一列，8b 的问题一眼就能看到 |
| EN6-06 | P1 | 推荐表；`MODELS.md` | 14b 在英语上会稳定地漏改几类错：`is exist`（要重组的动词）、`a HPLC`（字母缩写前的冠词）、`’, however` 的逗号粘连、间接问句语序。这些错非母语作者天天写。三次一样，再试也没用 | `MODELS.md` 里写明 14b「改得保守，可能漏改，不会乱改」，这是对用户诚实的描述。提示词可以试一句 `Also correct comma splices and the article before abbreviations (an HPLC, an RNA)`，但要先看会不会带来多改；不加也可以，漏改总比改坏好 |
| EN6-07 | P2 | `run.py` 的 `run_model`（`r.pop("raw")`） | JSON 只存清洗后的输出。清洗删掉了什么、模型还加不加星号、开头的套话还有没有，评审都看不到。这一轮我没法回答「EN4-02 在模型这一侧有没有好转」 | 同时存 `raw` 和 `output`，by-language 里清洗改动了输出时加一个标记（比如 `cleaned: emphasis`） |
| EN6-08 | P2 | `run.py` 的 `call_native`；§6.5「以截断结束」 | 三个模型 1224 次调用的 `finish` 全是 `None`：`chat.end` 里取 `stats.stop_reason` 没取到。截断检查现在形同虚设，这一轮只是因为都不思考、句子都短才没出事 | 先在一次调用里把 `chat.end` 的结构打印出来，找到真正的结束原因字段；取不到时记为「未知」而不是放行，并在 summary 里统计 |
| EN6-09 | P2 | `corpus.json`；by-language 的分组 | 第 4 轮我评了 5 条译成英语的条目（zh-en-1、fr-en-1、de-en-1、es-en-1、ja-en-1），这一轮它们没有 `review_lang`，按源语言分到了别人的文件里。英语译文的地道程度（`voted a budget`、`Euros`、对话破折号）没有英语母语的人看了 | 译成英语的条目给 `review_lang: "en"`，或者同时出现在两种语言的文件里。目标是英语的条目一并按 EN4-10 改成 `British English`（至少一部分） |
| EN6-10 | P2 | `corpus.json` en-r4-12 | note 写「译成英式英语」，`target` 却是 `English`，期望结果用 `3 March 2026`。这条因此三个模型 9 次全部「和期望不同」，机械统计里算成了模型的错 | 和 EN4-10 一起改；在改之前，这条的期望结果不该计入 `expect match` |
