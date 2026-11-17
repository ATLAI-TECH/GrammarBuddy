# Jonas（德语）— 多语言复评 Round 6

## 结论

三个 Qwen3 在德语上都不能让人在所有操作里「不看就按 ⏎」。最接近的是 **qwen3-14b**：改错 33 次里 18 次可直接用、只有 4 次不能用，翻译 12 次全部可直接用，没有一次删词或改坏原意。但它的润色 3 次都把德语原文**译成了英语**，语气 3 次原样返回。**qwen3-8b** 改错几乎不动手（33 次里 24 次不能用，大多是原样或几乎原样返回）。**qwen3-4b** 改得多，但会带进新错：ß、换掉奥地利用词、新的错别字、„Partei“，而且这些机械检查都拦不住。

按内存推荐（只针对德语）：

- **24 GB 以上**：qwen3-14b，可以用于改错和翻译。改错仍要扫一眼差异：它会漏改，但不会改坏。润色和语气在提示词修好之前不要用（DE6-01、DE6-06）。
- **16 GB**：没有好选择。qwen3-8b 的翻译可以用，改错不该推荐，因为它不改，用户还以为「没有错」。14b（8.4 GB）在 16 GB 上能不能跑，这次没有数据。德语用户建议用 API；如果实测 14b 在 16 GB 上跑得动，就推荐 14b。
- **8 GB**：只有 qwen3-4b 放得下。翻译基本可用；改错必须对照原文看，不能说「按 ⏎ 就行」。润色不能用。
- **不该推荐给德语改错**：qwen3-8b（不改）和 qwen3-4b（改出新错）。

和第 4 轮的 gemma-4 比，**明显变好**：思考和空输出都没了，用时从 9–32 秒降到 0.2–1.9 秒；14b 在 de-fix-2 上给出了正确改法，第 4 轮 e4b 在这里删了 „müssen“。润色是唯一变坏的地方：第 4 轮 e4b 的润色可直接用，这一轮 4b 和 14b 输出的是英语。

## 统计

按「条目 × 次」计。德语共 17 条，每条 3 次，每个模型 51 次。

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| qwen3-4b-2507 | 16 | 13 | 22 |
| qwen3-8b | 18 | 6 | 27 |
| qwen3-14b | 30 | 11 | 10 |

按操作分：

| 模型 | 改错（11 条，33 次） | 翻译（4 条，12 次） | 润色和语气（2 条，6 次） |
|---|---|---|---|
| qwen3-4b-2507 | 10 / 8 / 15 | 6 / 5 / 1 | 0 / 0 / 6 |
| qwen3-8b | 9 / 0 / 24 | 9 / 3 / 0 | 0 / 3 / 3 |
| qwen3-14b | 18 / 11 / 4 | 12 / 0 / 0 | 0 / 0 / 6 |

评分标准：

- **可直接用**：按 ⏎ 放回去，我作为 Lektor 不会再动。
- **小问题**：比原文好，没有引入新错，但漏了一处次要的错，或者有一处措辞我会改。
- **不能用**：符合下面任一种情况。
  - 引入了新错，或者改变了原意、语言、地区写法。
  - 主要的错一处都没改，包括原样返回。
  - 没有完成操作，例如语气没变。

## 逐条评分

| 条目 | 模型 | 次 | 结论 | 说明 |
|---|---|---|---|---|
| de-fix-1 | 4b | #1 | 可直接用 | „des Experiments zeigen, dass … auf die Blütezeit“，四处全改对。 |
| de-fix-1 | 4b | #0、#2 | 小问题 | 改了三处，漏了 „Einfluss auf der Blütezeit“（„Einfluss auf“ 要第四格，应为 „auf die“）。没有新错。 |
| de-fix-1 | 8b | #0–2 | 不能用 | 只把 „das“→„dass“。„des Experiment zeigt“ 和 „auf der“ 都没动。主谓不一致还在（„Die Ergebnisse … zeigt“）。 |
| de-fix-1 | 14b | #0–2 | 小问题 | „zeigen“、„dass“、„auf die“ 改对，漏了第二格词尾：„des Experiment“ 应为 „des Experiments“。 |
| de-fix-2 | 4b | #0–2 | 小问题 | 核心改对了：„denke, dass wir noch einige Änderungen machen müssen“，„müssen“ 挪到了句末，没有像第 4 轮那样被删。漏了两处：„bevor“ 前的逗号是必需的；„es“ 指 der Bericht，应为 „ihn“。在小问题和不能用的边缘：一句里还剩两处错。 |
| de-fix-2 | 8b | #0–2 | 不能用 | 只加了 „denke,“ 并把 „Änderungen“ 大写。„das wir müssen noch …“ 原样保留，句子的主要错误一处没改。 |
| de-fix-2 | 14b | #0–2 | 可直接用 | 和期望逐字相同：„…, dass wir noch einige Änderungen machen müssen, bevor wir ihn einreichen.“ 连 „ihn“ 都改了。 |
| de-fix-3 | 4b | #0–2 | 可直接用 | „obwohl wir Karten für das Konzert hatten“ 改对。„zuhause“ 没动，这是对的（允许的写法）。不定式前加的逗号可加可不加。„wegen dem“ 没动，按我第 4 轮的意见改错默认不动它。 |
| de-fix-3 | 8b | #0–2 | 不能用 | 只加了一个可有可无的逗号，„obwohl wir hatten Karten“ 没改。 |
| de-fix-3 | 14b | #0–2 | 可直接用（有争议） | obwohl 从句改对，„zuhause“ 没动。它把 „Wegen dem schlechten Wetter“ 改成了 „Wegen des schlechten Wetters“。这一处有争议：书面语里应该改，但这句是口语叙述。和第 4 轮一样，我不让它影响结论。 |
| de-polish-1 | 4b | #0–2 | 不能用 | **输出是英语**：„We used the procedure because it is fast and easy to carry out, …“。润色变成了翻译，见 DE6-01。 |
| de-polish-1 | 8b | #0–2 | 小问题 | „Wir haben das Verfahren verwendet, weil es schnell ist und leicht umzusetzen ist, und die Ergebnisse waren ebenfalls ziemlich gut.“ 语法正确，比原文好得多。„ist … ist“ 重复，细心的作者会写 „weil es schnell und leicht umzusetzen ist“。保留了 „ziemlich“，语域没变。 |
| de-polish-1 | 14b | #0–2 | 不能用 | **输出是英语**：„We used the procedure because it is fast, easy to perform, …“。#2 把 „have been“ 换成 „were“，同样是英语。 |
| de-en-1 | 4b | #0–2 | 可直接用 | „closed for six weeks starting March 3 … around 2.5 million euros“。数字、日期、货币名小写都对，比第 4 轮的 e4b 好。 |
| de-en-1 | 8b | #0–2 | 可直接用 | „closed from March 3rd for six weeks … approximately 2.5 million euros“。语序跟着德语走，但英语里可以接受，意思准确。 |
| de-en-1 | 14b | #0–2 | 可直接用 | 和 4b 基本相同，„about 2.5 million euros“。 |
| en-de-1 | 4b | #0–2 | 小问题 | Sie 选对了。„call me“ 译成 „mich zu kontaktieren“，「打电话」变成了「联系」，信息变宽了。„Bitte senden Sie mir … bis Freitag“ 可以，„zusenden“ 更地道。 |
| en-de-1 | 8b | #0–2 | 小问题 | „Schicken Sie mir den unterschriebenen Vertrag bis Freitag.“ **„Please“ 丢了**。德语商务信里不带 „bitte“ 的命令句很生硬，我不会让它这样发出去。只差一个词，所以记小问题；更严格的读者会判不能用（有争议）。 |
| en-de-1 | 14b | #0 | 可直接用 | „Schicken Sie mir bitte den unterschriebenen Vertrag bis Freitag zu. Wenn Sie Fragen haben, zögern Sie nicht, mich anzurufen.“ „zuschicken“ 很地道，„bitte“ 也在。 |
| en-de-1 | 14b | #1、#2 | 可直接用 | 同上，只是 „Wenn“ 换成 „Falls“，两种都对。 |
| de-r4-1 | 三个模型 | #0–2 | 可直接用 | 9 次全部原样返回：„Wegen Umbau“、„zuhause“、„3. März“ 都保住了。第 4 轮担心的「把对的改了」在这条上没有发生。 |
| de-r4-2 | 4b | #0–2 | 不能用 | „Ich glaube, dass er hat gesagt, dass er kommt nicht, weil er muss arbeiten.“ 逗号和两个 „dass“ 改了，三个从句的动词位置**一个都没动**。德语读者一眼就看出这句还是错的。 |
| de-r4-2 | 8b | #0–2 | 不能用 | 原样返回。 |
| de-r4-2 | 14b | #0–2 | 不能用 | „Ich glaube, das er hat gesagt, dass er kommt nicht, weil er muss arbeiten.“ 第一个 „das“ 没改，动词位置也没动。三个模型 9 次全部失败，见 DE6-03。 |
| de-r4-3 | 4b | #0–2 | 可直接用 | 和期望逐字相同。名词化（„Beim Schreiben“、„im Allgemeinen“、„nichts Besonderes“）和 „Wildtyp“ 都大写了，`flc-3` 保持小写，`FLC` 保持大写。 |
| de-r4-3 | 8b | #0–2 | 不能用 | 原样返回，五处大写错误都还在。 |
| de-r4-3 | 14b | #0–2 | 小问题 | 只漏了 „im allgemeinen“，按现行正字法应为 „im Allgemeinen“。其余全对，`flc-3` 和 `FLC` 都保住了。 |
| de-r4-4 | 4b | #0–2 | 不能用 | 只改了 „Ihnen“。„Könnten sie … ob sie …“ 没改，读出来是「他们能不能告诉我，他们是否……」，第二句却是「我昨天寄给您了」。称呼在一段里前后不一，比原文更乱。 |
| de-r4-4 | 8b | #0–2 | 可直接用 | 和期望逐字相同。 |
| de-r4-4 | 14b | #0–2 | 可直接用 | 和期望逐字相同。 |
| de-r4-5 | 4b | #0–2 | 不能用 | **引入了新的错别字** „DNA-Seqenzierung“（少了 u），还把 „10 Tage alten“ 改成了错误的 „10-Tage-alten“。„E-Mail-Adresse“ 和 „Col-0-Pflanzen“ 改对了。机械检查报了 `dropped_words`，但报的理由（„adresse“ 被删）是错的，见 DE6-05。 |
| de-r4-5 | 8b | #0–2 | 不能用 | 原样返回：„Email Adresse“、„DNA Sequenzierung“、„Col-0 Pflanzen“ 的分写错误都还在。 |
| de-r4-5 | 14b | #0、#1 | 小问题 | „Email-Adresse und … DNA-Sequenzierung … 10 Tage alten Col-0-Pflanzen“。连字符都对，„10 Tage alten“ 也保住了。„Email“ 按 Duden 应为 „E-Mail“（„Email“ 本义是搪瓷），不过 „Email-Adresse“ 在日常文字里很常见（有争议）。机械检查误报了 `dropped_words`。 |
| de-r4-5 | 14b | #2 | 可直接用 | 和期望逐字相同，**但机械检查报了 `dropped_words: adresse, sequenzierung`**。按设计稿 §6.5，这个完全正确的结果会被拦住，不能按 ⏎，见 DE6-05。 |
| de-r4-6 | 4b | #0–2 | 不能用 | „Die Straße … grossen … zu Fuß“：给瑞士写法塞进两个 ß，还和没改的 „grossen“ 混在一起。瑞士读者要逐个撤回。检查没报，见 DE6-04。 |
| de-r4-6 | 8b | #0–2 | 不能用 | 大写改了，但写成 „zu Fuß“。全文只有这一个 ß，夹在 „Strasse“ 和 „grossen“ 之间，是新引入的不一致。只错一个词，但违反了这条唯一的考点。 |
| de-r4-6 | 14b | #0、#1 | 可直接用 | 和期望逐字相同，一个 ß 都没有。 |
| de-r4-6 | 14b | #2 | 不能用 | 原样返回，„zu fuss“ 没改。这是一对一错，见「稳定性」。 |
| de-r4-7 | 4b | #0–2 | 不能用 | 把奥地利用词 „heuer“ 换成 „dieses Jahr“。改错里换掉一个正确的词，奥地利用户每次都要撤回。检查没报：一个词换成两个词，在词保留检查里算「替换」，见 DE6-04。 |
| de-r4-7 | 8b | #0–2 | 可直接用 | 原样返回。 |
| de-r4-7 | 14b | #0–2 | 可直接用 | 原样返回。 |
| de-r4-8 | 4b | #0 | 小问题 | „das“ 改对，„habe,“ 的逗号加了，„morgen“ 小写改对了。漏了 „spannender, als ich dachte“ 的逗号：als 引出带动词的从句，逗号是必需的。引号和引号后的逗号都保住了。 |
| de-r4-8 | 4b | #1、#2 | 小问题 | 同 #0，但还漏了 „Morgen“→„morgen“。一句里剩两处小错，在边缘。 |
| de-r4-8 | 8b | #0–2 | 不能用 | 只补了 „habe,“ 的逗号。关系代词 „dass“ 没改成 „das“，这是这条的主考点。„Morgen“ 也没改。 |
| de-r4-8 | 14b | #0–2 | 小问题 | 和 4b #0 一样，只漏了 als 前的逗号。 |
| de-r4-9（语气：友好） | 4b | #0–2 | 不能用 | 只把 „Senden“ 换成 „Schicken“，„Verspätete Einsendungen werden nicht berücksichtigt.“ 原样不动，语气没有变友好。Sie 和事实都在，但那是因为几乎什么都没改。 |
| de-r4-9 | 8b | #0–2 | 不能用 | 原样返回。 |
| de-r4-9 | 14b | #0–2 | 不能用 | 原样返回。三个模型 9 次没有一次完成「变友好」，见 DE6-06。 |
| de-r4-10 | 4b | #0、#2 | 可直接用 | „3,4 % auf 2,5 Milliarden Euro … 1.250 Mitarbeiter. „Wir sind sehr zufrieden“, sagte der CEO.“ 「Milliarden」、小数逗号、千位点、百分号前的空格、„…“ 引号、引号外的逗号全对。„verfügt nun über“ 是自然的书面德语。 |
| de-r4-10 | 4b | #1 | 可直接用 | 同上，只是 „Wir sind sehr erfreut“，略书面，没错。 |
| de-r4-10 | 8b | #0–2 | 可直接用 | „… 2,5 Milliarden Euro und das Unternehmen beschäftigt nun 1.250 Mitarbeiter.“ „und“ 前不加逗号，按现行规则可加可不加。 |
| de-r4-10 | 14b | #0、#1 | 可直接用 | „sagte der Geschäftsführer“：把 CEO 译成 „Geschäftsführer“，对 GmbH 是准确的说法，对 AG 应是 „Vorstandsvorsitzender“。德语媒体也常直接写 „CEO“。这是可接受的选择，不算错。 |
| de-r4-10 | 14b | #2 | 可直接用 | 保留 „CEO“，其余同上。 |
| de-r4-11 | 4b | #0、#2 | 小问题 | „Hey, kommst du zum Partyabend heute Abend?“ du 用对了，全文一致。但 „Partyabend heute Abend“ 叠了两个 Abend，不是母语者会说的话。 |
| de-r4-11 | 4b | #1 | 不能用 | „Hey, kommst du zum Partei abends?“ „Partei“ 是政党，词性还配错了（„zum“ 配阴性词）；„abends“ 是「每天晚上」，不是「今晚」。意思错了。 |
| de-r4-11 | 8b | #0–2 | 可直接用 | 和期望逐字相同。 |
| de-r4-11 | 14b | #0–2 | 可直接用 | 和期望逐字相同。 |

## 和第 4 轮比

只看第 4 轮就有的 6 条，每个模型按 6 条 × 3 次 = 18 次计：

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| gemma-4-e4b（R4，每条 1 次，共 6 次） | 3 | 1 | 2 |
| gemma-4-12b（R4，每条 1 次，共 6 次） | 3 | 0 | 3 |
| qwen3-4b（R6） | 7 | 8 | 3 |
| qwen3-8b（R6） | 3 | 6 | 9 |
| qwen3-14b（R6） | 12 | 3 | 3 |

- **变好了**：
  - 速度：中位数 0.34 / 0.6 / 1.02 秒，最长的一条德语也没超过 1.9 秒。第 4 轮是 9–32 秒，现在全部达到 §6.6 的 2 秒目标。
  - 不再有空输出，也不再思考。
  - **没有一次删词**：de-fix-2 里三个模型都留住了 „müssen“，4b 和 14b 还把它挪到了句末。第 4 轮最严重的 DE4-01 这次在德语上没有复现。
  - 14b 的改错质量明显高于第 4 轮的 e4b：de-fix-2 逐字正确，de-fix-3 没有像 e4b 那样乱挪 „zu Hause“。
- **变坏了**：
  - 润色：第 4 轮 e4b 的 de-polish-1 是可直接用，这一轮 4b 和 14b 6 次全是英语。
  - 风险的类型也变了。第 4 轮的错是「删词」，现在已有检查对付它；这一轮 4b 的错是「换写法、换用词、生错字」（ß、„dieses Jahr“、„Seqenzierung“），现有检查一样都抓不到。
- **新问题**：8b 的失败方式是「不改」。不改本身不伤稿子，但用户会以为「模型看过了，没有错」。

## 稳定性

在德语上，8b 的 17 条三次输出完全相同；4b 有 4 条不同，14b 有 5 条不同。

**一次对一次错**的两条：

| 条目 | 模型 | 对的 | 错的 |
|---|---|---|---|
| de-r4-11 | 4b | #0、#2：„zum Partyabend heute Abend“（小问题） | #1：„zum Partei abends“（不能用，意思错） |
| de-r4-6 | 14b | #0、#1：„zu Fuss“（= expected） | #2：原样返回 „zu fuss“（没改） |

同一个结论档里有差异，或者对错只差一处的：

- 4b de-fix-1：#1 全对，#0 和 #2 漏了 „auf die“。
- 4b de-r4-8：#0 改了 „morgen“，#1 和 #2 没改。
- 14b de-r4-5：#2 写 „E-Mail-Adresse“，#0 和 #1 写 „Email-Adresse“。
- 4b de-r4-10 #1 „erfreut“ 对 „zufrieden“，14b de-r4-10 „Geschäftsführer“ 对 „CEO“，14b en-de-1 „Wenn“ 对 „Falls“，14b de-polish-1 „were“ 对 „have been“：都不影响结论。

所以「跑一次看着对」不等于「每次都对」，差别在温度 0.2 下就会出现。用户按两次快捷键得到两个不同结果，见 DE6-07。

## 设计和提示词的问题

### 第 4 轮的问题现在怎样了

| R4 ID | 现状 |
|---|---|
| DE4-01 删词 | **已处理**：§6.5 加了词保留检查，提示词加了「不能删词」，差异视图区分移动和删除。德语这轮没有删词。但这项检查本身在德语复合词上误报，见 DE6-05。 |
| DE4-02 比例检查误报 | **已处理**：§6.5 去掉了改错的比例阈值。 |
| DE4-03 思考 | **已处理**：三个模型 0 次思考，速度达标。但 §6.6 的表格和 §7.2 的文字还写着「思考关不掉」「41 条里只有 4 条没思考」，过时了（DE6-09）。 |
| DE4-04 大小写误报 | **设计稿已处理**（§6.4 收窄到像记号的词）。但 `run.py` 没有实现大小写这一项，summary 里的「protected missing 0」不能证明它在德语上不误报。de-r4-3 里 4b 和 14b 都保住了 `flc-3` 和 `FLC`。 |
| DE4-05 带连字符的记号 | **一半**：`run.py` 的保护项是按子串查的，„Col-0-Pflanzen“ 没有误报。§6.4 的文字没写明要按子串查。新的误报出在词保留检查上（DE6-05）。 |
| DE4-06 允许的变体和口语用法 | **提示词没改**。实际表现好：9 次 de-r4-1 全部保留 „zuhause“，de-fix-3 也没人动 „zuhause“。14b 仍把 „wegen dem“ 改成第二格（有争议）。语料 de-fix-3 的考点还写着 „zu Hause; Komma vor Infinitivgruppe“，没按建议分成「必须改 / 可改可不改 / 不许改」（DE6-08）。 |
| DE4-07 「不调语序」 | **没改**：§6.1 仍是「不换词、不调语序」，`fix.txt` 仍是 `do not reorder sentences`。这一轮的问题从「乱挪」变成了「该挪的不挪」（DE6-03）。 |
| DE4-08 Sie / du | **提示词没改**。实测两个方向都选对了：en-de-1 9 次都是 Sie，de-r4-11 9 次都是 du。降为 P2，规则仍建议写进提示词（DE6-10）。 |
| DE4-09 瑞士和奥地利写法 | **没改**，而且现在**有数据证明风险是真的**：ß 被引入 6 次，„heuer“ 被换掉 3 次（DE6-04）。 |
| DE4-10 复合词的字符级差异 | **一半**：§6.5 加了「只差一个字母时做字符级标记」。分写、合写、加连字符的互转还没有说法；4b 的 „Seqenzierung“ 正好需要字符级标记才看得出来。 |
| DE4-11 换语气时称呼跟着变 | 语料加了 de-r4-9，但模型根本没换语气，所以测不出称呼会不会变（DE6-06）。 |
| DE4-12 保护词变格 | 没改，这一轮没有相关数据。 |
| DE4-13 德语语料太少 | **已处理**：我建议的 12 句都加了，大部分带期望结果。 |

### 新问题

| ID | P0/P1/P2 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| DE6-01 | P0 | `prompts/polish.txt`；`run.py` 的 `system_prompt`（语言要求拼在最后）；§6.1（「语言不变」只写在改错一行）；§6.5（没有语言检查） | **润色把德语译成英语。** de-polish-1 上 4b 和 14b 6 次全是英语，机械检查一项都没报。看其他语言的结果文件，这不是德语独有的：fr-polish-1、fr-r4-14、zh-polish-1、es-r4-16 上 4b 都输出英语，14b 在 fr-polish-1、zh-polish-1、ja-r4-16 上也是。改错没有出现这种情况。我推测有两个原因：`polish.txt` 开头的 „the way a careful native writer would put it“ 没说是哪种语言；「Reply in the same language」排在 system 消息最后，分量不够。这只是推测，要重跑才能确认。用户按 ⏎ 后，德语论文里会多出一段英语。 | 1. 提示词开头就写明语言，用 App 检测到的语言名填进去：`The text is in German. Rewrite it in German.` 不要只靠「same language」。2. §6.5「所有操作」加一项：改错、润色、语气的输出用 `NLLanguageRecognizer` 判语言，和原文不同就算异常；可以自动重试一次，仍不同就不提供放回原处，和截断同等处理。3. `run.py` 加同样的检查，让 summary 能直接显示这种情况。4. §6.1 的「语言不变」写到四种操作的公共要求里。 |
| DE6-02 | P1 | §7.5 推荐模型；面板「没有改动」时的文案 | **8b 在德语改错上几乎不动手**：11 条改错里 5 条原样返回（de-r4-2、de-r4-3、de-r4-5，以及本来就没错的 de-r4-1 和 de-r4-7），另有 5 条只改了一个逗号或一两个词（de-fix-1、de-fix-2、de-fix-3、de-r4-6、de-r4-8），只有 de-r4-4 改完整了。它的「= expected」看着不差（12/36），但其中 6 次是两条本来就该原样返回的句子。用户看到「没有修改」，会理解成「没有错误」。 | 1. 推荐表按语言写：德语改错不推荐 8b。2. 改错结果和原文相同时，面板写「模型没有做任何修改」，不写「没有发现错误」。3. 语料的评分除了「= expected」，再加一项「该改的改了几处」（召回）。只看「= expected」和 `dropped_words`，会把不改的模型评得很安全。 |
| DE6-03 | P1 | `prompts/fix.txt`（`Change as little as possible … do not reorder sentences`）；§6.1（「不调语序」） | **从句动词末位，德语学习者最典型的错，没有一个模型在 de-r4-2 上改对（9/9 失败）。** 4b 和 14b 在 de-fix-2 和 de-fix-3 上能挪动词，到了三个从句叠在一起的句子就只补逗号和 „dass“。原因可能是提示词里「尽量少改」「不调语序」压住了必要的挪动（推测，有争议）。 | 采用 DE4-07 的写法：§6.1 改成「语序只在语法要求时才动（例如从句的动词位置）」。`fix.txt` 把 `do not reorder sentences` 换成 `Change word order only where grammar requires it (for example verb position in German subordinate clauses); leave correctly placed words where they are.` 改完重跑 de-r4-2、de-fix-2、de-fix-3，看能不能挪对，同时不乱挪。 |
| DE6-04 | P1 | `prompts/_common.txt`（`British stays British`）；§6.1（「按用户选的英语拼写变体」）；§6.5 | **瑞士和奥地利写法被「改正」，检查全拦不住。** de-r4-6 上 4b 引入了 „Straße“ 和 „Fuß“，8b 引入了 „Fuß“（6 次）。de-r4-7 上 4b 把 „heuer“ 换成 „dieses Jahr“（3 次）。词保留检查把一个词换成两个词算作「替换」，放行了。 | 1. 按 DE4-09：德语分德国、奥地利、瑞士三个变体；`_common.txt` 加 `Swiss German keeps ss instead of ß; Austrian words (Jänner, heuer, Sessel) stay as they are`。2. 加一项便宜的机械检查：原文一个 ß 都没有，结果里出现了 ß，就标橙。3. 改错时，替换前后两个词字符相似度很低的（„heuer“→„dieses Jahr“），按「换了词」标出来。改错本来就不该换掉正确的词，这能补上词保留检查的空当。 |
| DE6-05 | P1 | §6.5 词保留检查；`run.py` 的 `tokens` / `dropped_words`；§9 第 15b 项 | **德语里补连字符的正确改错被判为丢词。** 分词把 „E-Mail-Adresse“ 当成一个词，原文的 „Adresse“ 就「不见了」。de-r4-5 上 14b 的 3 次全被报，其中 #2 和期望逐字相同。照 §6.5，这个完全正确的结果不能按 ⏎。反过来，4b 真正的问题（新错字 „Seqenzierung“、错的 „10-Tage-alten“）只是碰巧被同一条误报带出来，报的理由是错的。德语里分写改连写是很常见的改错（DE4-05 的例子）。 | 1. 比对前，被替换的一段两边都去掉连字符和空格再比，相同就算「合写 / 加连字符」，不算丢词，差异视图显示成「连起来了」。2. 另加一项：替换前后只差一两个字母，并且新词不在系统拼写词典里、旧词在，就提示「可能引入了拼写错误」（`NSSpellChecker`）。这正好抓住 „Seqenzierung“。3. §9 第 15b 项实测 NLTokenizer 怎么切 „E-Mail-Adresse“、„Col-0-Pflanzen“、„10-jährig“。 |
| DE6-06 | P1 | `prompts/tone.txt`；`corpus.json` 的 de-r4-9 | **「友好」语气没有生效**：9 次里 6 次原样返回，3 次只换了一个动词（„Senden“→„Schicken“）。`tone.txt` 只有一句「Rewrite the text in a friendly tone」，后面拼上的 `_common.txt` 却通篇是「保持原样」，模型很可能就照字面「保持」了（推测）。因为什么都没改，DE4-11 要测的「Sie 会不会变成 du」这次测不出来。 | 1. `tone.txt` 写明可以改什么：`Change wording and sentence structure as needed so that it sounds {TONE}. Keep the form of address (Sie / du, vous / tu, usted / tú) and every fact.` 2. 语气的输出和原文相同时，面板提示「语气没有变化」，不当作成功的结果。3. 德语再加一条「正式」方向的语气测试（du → 应保持 du，只改措辞）。 |
| DE6-07 | P2 | §7.2（「温度 0.2」）；`run.py` | **温度 0.2 下同一句结果会一对一错**（4b de-r4-11 的 „Partei“，14b de-r4-6 的漏改）。改错和翻译不需要多样性。 | 改错和翻译用温度 0。重跑三次，看德语上的差异是否消失。润色和语气可以保留 0.2。 |
| DE6-08 | P2 | `corpus.json` 德语部分 | 第 4 轮就有的 6 条，德语只有 de-fix-2 补了期望结果。de-fix-3 的考点仍把 „zu Hause“ 和不定式逗号列为必须改。de-fix-2 的 note 里直接拼进了我第 4 轮报告的中文原句，没有转成考点。 | 给 de-fix-1、de-fix-3、de-polish-1、de-en-1、en-de-1 补期望结果。考点分成「必须改 / 可改可不改 / 不许改」三栏。de-fix-3 必须改的只有 obwohl 从句的动词位置；„wegen dem“ 和逗号属于可改可不改；„zuhause“ 不许改。 |
| DE6-09 | P2 | DESIGN §6.6 表格、§7.2「思考」一条、§7.5；`docs/MODELS.md` | 设计稿和 MODELS.md 还停在 gemma-4 的结论（「思考关不掉」「41 条里只有 4 条没思考」「5–23 秒」）。这一轮 Qwen3 关掉思考后中位数 0.3–1.0 秒，这些文字已经不对。 | 本轮评审汇总后更新这三处。速度和质量按语言分别记；德语的推荐按本报告的结论写。 |
| DE6-10 | P2 | `prompts/translate.txt` | 译成德语时 Sie / du 没有规则（DE4-08 未改）。这轮碰巧都选对了。另外，8b 把 „Please“ 漏了，4b 把 „call“ 泛化成 „kontaktieren“：提示词里已经有 `do not add or omit information`，礼貌用语还是会丢。 | 按 DE4-08 写进规则：按语域判断，判断不出就用 Sie，全文一致。另加一句 `Keep politeness markers such as please / bitte.` |
