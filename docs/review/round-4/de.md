# Jonas（德语）— 多语言评审 Round 4

## 结论

两个模型在德语上现在都不能让人「不看就按 ⏎」：gemma-4-e4b 的翻译和润色可用，但三条改错里有两条改坏了句子（删掉情态动词 „müssen“、把 „zu Hause“ 挪到错的位置），而且现有的检查一条也拦不住；gemma-4-12b 在四条改错和润色里有三条思考到用完 token、输出为空，只有翻译可用。

## 逐条评分

共 6 条，每条两个模型。

| 条目 | 模型 | 该改的改了吗 | 改坏或多改 | 结论（可直接用 / 小问题 / 不能用） | 说明 |
|---|---|---|---|---|---|
| de-fix-1 | e4b | 全改了：„des Experiments“、„zeigen“、„dass“、„auf die Blütezeit“ | 没有 | 可直接用 | 输出无可挑剔，没有越界成润色。但等了 14.3 秒（思考 2277 字符），设计目标是 2 秒。 |
| de-fix-1 | 12b | 全改了，输出和 e4b 逐字相同 | 没有 | 可直接用 | 18.1 秒。 |
| de-fix-2 | e4b | 部分：加了 „denke,“ 和 „machen,“ 两个逗号，„das“→„dass“，„Änderungen“ 大写。**没改** „es“→„ihn“（der Bericht 是阳性） | **改坏**：为了把动词放到从句末尾，直接把 „müssen“ 删了 | **不能用** | 原文是「我们还必须做些修改」，输出 „dass wir noch einige Änderungen machen, bevor wir es einreichen“ 变成「我们还会做些修改」，义务没了。正确结果是 „…, dass wir noch einige Änderungen machen müssen, bevor wir ihn einreichen.“ 输出本身是合乎语法的德语，所以读结果读不出问题，只有对照原文才看得出来。这是本次最严重的一条，见 DE4-01。 |
| de-fix-2 | 12b | 没有输出 | — | 不能用 | 输出为空，`finish=length`，思考 4068 字符把 1024 token 的额度用完了。白等 31.6 秒。 |
| de-fix-3 | e4b | „obwohl wir Karten für das Konzert hatten“ 改对了。„wegen dem“→„wegen des … Wetters“（有争议，见下）。不定式短语前的逗号没加（这里按 Duden 是可加可不加，不算错） | **改坏**：„haben wir uns zu Hause entschieden zu bleiben“。**多改**：„zuhause“→„zu Hause“ | **不能用** | 模型把 „zu Hause“ 从不定式短语里挪到了 „entschieden“ 前面。这样读成「我们在家里做了决定，要留下」，而且 „bleiben“ 没了地点补足语，句子别扭。原文这一处的语序本来是对的，是模型自己搬出来的新错。正确结果：„…haben wir uns entschieden, zu Hause zu bleiben, obwohl wir Karten für das Konzert hatten.“ 另外 „zuhause“ 从 2006 年起是 Duden 承认的写法（Duden 推荐 „zu Hause“，但 „zuhause“ 不是错），改错不该动它。 |
| de-fix-3 | 12b | 没有输出 | — | 不能用 | 空输出，`finish=length`，31.5 秒。 |
| de-polish-1 | e4b | 改了：„verwendet, weil es … ist“（逗号和动词末位），三个 „und“ 的流水句收紧，„sind … gewesen“→„waren“ | 一处很轻的意思偏移 | 可直接用 | „weil es schnell und einfach anzuwenden ist und die Ergebnisse zudem recht gut waren“ 是一句干净的书面德语。原文 „es ist schnell“ 说的是方法本身快，输出里 „schnell“ 变成修饰 „anzuwenden“（用起来快）。在论文的方法部分，如果「快」指运行时间，这有差别；我作为 Lektor 会放过，但会在页边问作者一句。„das“→„dieses“、„ziemlich“→„recht“ 属于润色允许的范围。9.3 秒。 |
| de-polish-1 | 12b | 没有输出 | — | 不能用 | 空输出，`finish=length`，31.3 秒。 |
| de-en-1 | e4b | 数字和日期都转对了：„2.5 million“、„March 3rd“ | 没有改坏 | 小问题 | „2.5 million Euros“：英语里货币名小写，应为 „euros“。„closed starting March 3rd for six weeks“ 语序生硬，自然的说法是 „for six weeks starting March 3“。意思完全准确。10.1 秒。 |
| de-en-1 | 12b | 同上，都对 | 没有 | 可直接用 | „closed for six weeks starting March 3rd“、„2.5 million euros“，两处都比 e4b 好。„The costs amount to“ 是直译腔，但没错。14.5 秒。 |
| en-de-1 | e4b | 用了 Sie，正确 | 没有 | 可直接用 | „Bitte senden Sie mir den unterschriebenen Vertrag bis Freitag zu. Wenn Sie Fragen haben, zögern Sie nicht, mich anzurufen.“ 语法、逗号、大写都对。„zögern Sie nicht“ 是从英语 „don't hesitate“ 来的套话，商务信里很常见，不算错。**0.87 秒，没有思考**，是全部 12 个输出里唯一达到速度目标的。 |
| en-de-1 | 12b | 用了 Sie，正确 | 没有 | 可直接用 | „…den unterzeichneten Vertrag … Wenn Sie Fragen haben, können Sie mich gerne anrufen.“ 比 e4b 更地道：„unterzeichnet“ 是合同的惯用词，„können Sie mich gerne anrufen“ 正好对应 „feel free“。但等了 28.7 秒，是 e4b 的 33 倍。 |

汇总：

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| gemma-4-e4b | 3 | 1 | 2 |
| gemma-4-12b | 3 | 0 | 3 |

关于 „wegen dem“（**有争议**）：

- 一种看法：Duden 把 wegen + 第三格标为 „umgangssprachlich“，书面语里应改成第二格，Lektor 在稿子里一定会改。
- 另一种看法：这句话本身是口语叙述（买了音乐会的票，天气不好留在家），„wegen dem schlechten Wetter“ 在这种语域里完全可接受，改成 „wegen des schlechten Wetters“ 是把语气往书面拉，越过了「不改语气」。
- 我的判断：单看这一处，e4b 改成第二格我不算它错，也不算它对；它不该影响这条的结论。但语料把它列为考点的方式要改，见 DE4-06。

## 模型排名和推荐

1. **gemma-4-e4b**：翻译和润色可以推荐，改错不能。
   - 翻译两条都准确，润色一条达到了可以直接交稿的水平。
   - 改错三条里两条引入了新错，而且都是在处理语序时出的事。德语改错最核心的能力恰恰是把动词放对位置，它在这上面不可靠。
   - 给德语用户的说法应该是：「改错的结果必须对照原文看，尤其是从句末尾的动词。」
2. **gemma-4-12b**：按这次的配置不能推荐给德语用户。
   - 改错和润色四条里三条是空输出。它有输出的三条质量都好，en-de-1 比 e4b 更地道，de-en-1 也更好。
   - 所以问题不在语言能力，而在思考：它每次先写 3500 到 4500 字符的思考，1024 token 的额度不够。这是测试配置和模型的组合问题，但用户看到的就是等半分钟得到一片空白。
   - 如果关掉思考后它还能保持有输出那三条的质量，排名可能反过来。这一点文件里没有数据，我不下结论。

速度和质量的取舍：

- 12 个输出里 11 个带思考，用时 9 到 32 秒。唯一不带思考的一条（e4b 的 en-de-1）只用 0.87 秒，质量没有问题。从这一条看，思考对德语的简单任务没有带来看得见的好处。
- 相反的证据：e4b 在 de-fix-2 思考了 1641 字符、de-fix-3 思考了 2962 字符，照样改坏。思考没有防住错误。
- 对按快捷键改一句话的用户，10 秒以上已经比自己改还慢。我的建议是先解决思考的问题再谈推荐哪个模型，见 DE4-03。

## 设计和提示词的问题

下面的词数都按 `qa/model-eval/run.py` 的算法实算过（按空白切词，标点粘在词上）。设计稿 §6.5 没写切词方法，我假设实现会和它一致。

| ID | P0/P1/P2 | 位置（设计稿章节或提示词文件） | 问题 | 建议 |
|---|---|---|---|---|
| DE4-01 | P0 | §6.5 跑偏检查；§4.2 Diff；`prompts/fix.txt` | **改错时词被删掉，没有任何检查能发现，差异视图里也分不出「挪走」和「删掉」。** e4b 在 de-fix-2 删了 „müssen“，改动比例 26%，不触发 §6.5。我算了正确的改法（„…machen müssen, bevor wir ihn einreichen“），也是 19 个词里改 5 个、26%。按比例判断，对的和错的一模一样。更糟的是显示：德语改错经常要把动词从第二位挪到句末，词级差异会显示成「原位置删除，句末插入」。用户看惯了之后，见到 „müssen“ 上有删除线会默认它被挪到后面去了，不会去找。 | 1. 改错加一项机械检查：原文里的每个词，在结果里要么原样存在（位置不限），要么有一个拼写相近的词对应（„dem“→„des“、„Wetter“→„Wetters“、„das“→„dass“）。找不到对应的就是「被删掉的词」，用橙色标出并按 §2.4 第 2 条处理。结果里凭空多出的实词同理。2. 差异视图把「同一个词在同一句里换了位置」显示成移动（例如两处同色加箭头或下划线），和删除用不同的样式。3. 提示词加一句：`Never drop or add a word unless the word itself is the error.` |
| DE4-02 | P1 | §6.5 跑偏检查（改错：超过 40% 并且超过 8 个词） | **德语里完全正确、最小幅度的改错会被判为「改动过大」。** 原因有两个。一是每补一个逗号算改了一个词（„denke“→„denke,“），而德语从句前的逗号是强制的，漏逗号是母语者最常见的错。二是把动词挪到句末要算两个词（动词本身，加上原来句末那个带句号的词）。实算：„Ich glaube das er hat gesagt das er kommt nicht weil er muss arbeiten.“ 的最小改法是 14 个词里改 7 个，50%。接上第二句 „Wenn ich habe Zeit ich werde ihn anrufen und fragen ob er kann uns am Samstag helfen.“ 后是 31 个词里改 12 个，39%，刚好压线；再多一个小写的名词就是 13 个、42%，触发。这是德语学习者的典型文字，也正是最需要这个工具的人。触发后 ⏎ 变成复制，面板还提示结果异常。 | 1. 切词时把标点和词分开，只加减标点不计入改动词数。2. 换了位置但词本身没变的，不计或只计一次。3. 只改了大小写的不计。4. 更根本的办法：改错的跑偏检查不看「改了多少个位置」，改看 DE4-01 那项「原文的词有多少还在」。它不受语序和逗号影响，对德语的误报会少得多，同时能抓住真正的跑偏（内容被换掉）。 |
| DE4-03 | P1 | §6.2（「不带标记时 0.8 秒」）；§6.6 速度目标；§7.5 推荐模型 | **不带分隔标记，德语文本照样触发思考。** §6.2 的说法是去掉分隔标记后 e4b 回到 0.8 秒。这次德语的 4 条改错和润色，e4b 全部先思考（1560 到 2962 字符），用时 9 到 18 秒；12b 用时 18 到 32 秒，其中 3 条思考到截断。§6.6 的「改错 2 秒」在德语上一条也没达到。 | 1. 在请求里明确关掉思考，不要指望模型自己不想；关不掉的模型不进推荐表。2. `MODELS.md` 的速度按语言分别记，不能拿英文的 0.8 秒代表德语。3. 思考关不掉时，输出额度要把思考算进去，否则 12b 这种情况会一直是空输出。4. §6.5 已经规定空输出和截断时不提供放回原处，这一点是对的，保留。 |
| DE4-04 | P1 | §6.4 保护项检查，「只改了大小写的词（句首除外）」 | **这条检查在德语里会天天误报。** 德语所有名词大写，改大小写是最常见的改错之一：小写的名词（„änderungen“→„Änderungen“，就在 de-fix-2 里）、名词化（„beim schreiben“→„beim Schreiben“，„im allgemeinen“→„im Allgemeinen“，„nichts besonderes“→„nichts Besonderes“）、称呼（„sie“→„Sie“，„ihnen“→„Ihnen“）、反方向（„Morgen“→„morgen“，„Abends“→„abends“）。按现在的规则，每一处都是橙色的「保护内容被改动」，⏎ 变成复制。一封学习者写的邮件可以有十处。另外，冒号后面接完整句子时首词大写，也不属于「句首」。 | 把这条检查收窄到「看起来像记号的词」：全大写（`FLC`）、词中间有大写（`mRNA`、`pH`）、含数字、在保护词表里。普通词只改了首字母大小写的，不算保护项，按普通改动显示。剩下的漏洞是德语句子里全小写的基因名被模型当成名词大写（`flc`→`Flc`）：对不在系统德语词典里的短词（例如 5 个字母以内）保留这项检查。 |
| DE4-05 | P1 | §6.4 保护项检查，「带数字或连字符的记号」 | **德语用连字符连接复合词，漏写连字符是常见错误，改它会被当成动了保护项。** 例子：„Email Adresse“→„E-Mail-Adresse“，„DNA Sequenzierung“→„DNA-Sequenzierung“，„10 jährig“→„10-jährig“，„Col-0 Pflanzen“→„Col-0-Pflanzen“（Duden 的连写规则要求全部连上）。按词比较的话，`Col-0` 变成了 `Col-0-Pflanzen`，`10` 变成了 `10-jährig`，都会报。反过来，已经带连字符的普通复合词（„E-Mail-Adresse“、„pH-Wert“）变格时也会变（„des pH-Werts“）。 | 这一项改成按子串检查：原文里的记号（`Col-0`、`flc-3`、`10`）在结果里还作为一段连续的字符存在就算通过，不要求它仍然是一个独立的词。不含数字、只是普通词加连字符的（„E-Mail“），不当作记号。 |
| DE4-06 | P1 | §6.1 改错的定义；`prompts/fix.txt`；`corpus.json` 的 de-fix-3 | **改错没有说明「口语里可接受的用法」和「两种都对的写法」动不动。** e4b 在 de-fix-3 把 „wegen dem“ 改成第二格，把 „zuhause“ 改成 „zu Hause“。前者有争议（见上一节末尾），后者是把对的改了。语料的考点里把 „zu Hause“ 和「不定式短语前的逗号」都列为该改的，这两项都不成立：„zuhause“ 是允许的写法；这句的不定式短语没有 um / ohne / statt 引导，也没有指代词，逗号可加可不加。按现在的考点打分，会奖励多改的模型。 | 1. 提示词加一句：`Do not change spellings or constructions that are accepted variants (for example zuhause / zu Hause, optional commas), and leave colloquial but accepted usage alone unless the rest of the text is clearly formal.` 2. 语料的考点分成三栏：必须改、可改可不改、不许改。de-fix-3 里必须改的只有 obwohl 从句的动词位置；„wegen dem“ 和逗号是可改可不改；„zuhause“ 是不许改。3. 我作为 Lektor 的意见：正式文体里 „wegen dem“ 应该改，但这属于润色或「正式」语气该做的事。改错默认不动它，对用户更可预期。 |
| DE4-07 | P1 | §6.1（「不调语序」）；`prompts/fix.txt`（`do not reorder sentences`） | **设计稿的说法对德语不可行，提示词的说法含糊。** 德语的 V2 和从句动词末位错误只能靠调语序改，de-fix-2、de-fix-3、de-polish-1 三条的核心都是它。提示词写的是「不要调整句子的顺序」，可以理解成不调换句子之间的先后，所以模型实际上调了语序，这是对的。但它没有被告知边界在哪，结果 e4b 在 de-fix-3 把本来位置正确的 „zu Hause“ 也挪了。 | 设计稿 §6.1 改成：「不换词；语序只在语法要求时才动（例如从句的动词位置），不为了通顺而调」。提示词相应改成：`Change word order only where grammar requires it (for example verb position in German subordinate clauses); leave correctly placed words where they are.` 「改错只改错误」这个原则对德语本身是可行的，要改的只是「不调语序」这半句。 |
| DE4-08 | P1 | §2.5 翻译；`prompts/translate.txt` | **译成德语时用 Sie 还是 du 没有任何规则。** en-de-1 两个模型都选了 Sie，对这条商务文字是对的，但那是模型自己猜的，提示词里一个字没提。英语的 „you“ 不带这个信息，同一个模型遇到 „Hey, are you coming tonight?“ 会怎么选、会不会在一段话里前面 Sie 后面 du，这次的语料测不出来。默认引擎是系统翻译，它不读提示词，更没法指定。法语、西班牙语、意大利语、荷兰语有同样的问题。 | 1. 默认规则写进提示词：从原文的语域判断（问候语、称呼、缩写、表情符号）；判断不出来时用 Sie；**全文只用一种**。2. 面板在目标语言旁边给一个就地切换「Sie / du」，按目标语言记住上次的选择。用 AI 翻译时写进提示词；用系统翻译时这个开关不可用，并提示「要指定称呼需要用 AI 翻译」。3. 加一项便宜的机械检查：译文里同时出现句中大写的 „Sie / Ihnen / Ihr“ 和 „du / dir / dein“ 时提示「称呼不一致」。4. 系统翻译实际输出哪一种，需要实测后写进文档。 |
| DE4-09 | P1 | §6.1（「按用户选的英语拼写变体」）；§2.5 ⌘L 的地区变体；`prompts/_common.txt` | **地区变体只考虑了英语。** 瑞士德语不用 ß（„Strasse“、„gross“、„Grüsse“、„heisst“），这是正确的瑞士写法。提示词里只有一句 `British stays British`，模型很可能把它们全部「改正」成 ß。每一处改动单看都像是合理的改错，瑞士用户要逐个撤回。奥地利的用词（„Jänner“、„heuer“、„Sessel“）在润色时有被换成德国用词的风险。语料里没有这类句子，所以这次测不出来，我只能指出风险。 | 1. 德语也分变体：德国、奥地利、瑞士，和英语一样在「我的语言」里选。2. 没选的时候按原文判断：原文一个 ß 都没有、又出现了 „Strasse / gross / heisst / ausser“ 这类词，就当作瑞士写法，把「不要引入 ß」写进这次的提示词。3. `_common.txt` 的例子补上：`British stays British, Swiss German keeps ss instead of ß, Austrian words stay Austrian`。4. 译成德语时，瑞士变体的引号用 «…»，德国和奥地利用 „…“。 |
| DE4-10 | P2 | §4.2 Diff（词级差异） | 德语复合词很长，词级差异把整个词标成「替换」，用户看不出改了哪里。例如 „Schadenersatzforderung“ 和 „Schadensersatzforderung“ 只差一个 s；„Experiment“→„Experiments“、„Wetter“→„Wetters“ 也只差词尾。把分开写的复合词合起来（„Blüte Zeit“→„Blütezeit“）会显示成删两个词、加一个词。 | 被替换的一对词如果大部分字符相同，就在词内再做一次字符级差异，只高亮变了的字母。分写和合写互相转换的，显示成「去掉空格」或「加上空格」，不显示成换词。 |
| DE4-11 | P2 | `prompts/tone.txt`；`corpus.json` | 语料里没有德语的换语气。德语换语气最大的风险是称呼跟着变：「友好」把 Sie 改成 du，或者「正式」把 du 改成 Sie。这改变的是作者和读者的关系，不只是语气，而且有时是真的冒犯。 | 提示词加一句：`Keep the form of address (Sie / du, vous / tu, usted / tú) unless the user asked to change it.` 语料加一条德语的换语气，见下一节第 9 条。 |
| DE4-12 | P2 | §6.4 保护词表（区分大小写） | 德语的专有名词和术语会变格：保护词 „Müller“ 在 „Müllers Bericht“ 里、保护词 „Verfahren“ 在 „des Verfahrens“ 里都带词尾。按整词比较的话，模型正确地加上或去掉第二格的 -s 也会报「保护词被改」。 | 保护词在结果里以它为开头的词出现（后面只多出 -s、-es、-n、-en、-e 这类词尾）也算通过。 |
| DE4-13 | P2 | `corpus.json` 德语部分 | 德语只有 6 条，没有一条是「本来就对、应该原样返回」的，也没有瑞士或奥地利写法、名词大写、复合词连字符、Sie 和 sie 的区别、引号、译成德语时的数字格式。这次最重要的几个风险（DE4-04、05、08、09）都因此没有实测数据。 | 加下一节的句子。 |

对任务里几个具体问题的直接回答：

- **「只改错误、不换词不调语序」对德语可行吗**：「不换词」可行。「不调语序」不可行，必须改成「语序只在语法要求时才动」（DE4-07）。
- **按改动词数比例判断会不会误判**：会。两句典型的学习者德语，最小改法就到 39% 到 42%（DE4-02）。同时这个比例抓不住真正危险的情况：删掉 „müssen“ 和正确改法的比例都是 26%（DE4-01）。
- **„wegen dem“ 改错该不该动**：默认不动，留给润色和正式语气（DE4-06）。这一点有争议，两种看法都写在上面了。
- **英译德的 Sie / du**：按原文语域判断，判断不出用 Sie，全文一致，并给用户一个就地切换（DE4-08）。
- **复合词和名词大写对 §6.4 的影响**：「只改了大小写的词」这条在德语里会天天误报，要收窄到看起来像记号的词（DE4-04）；带连字符的记号要按子串检查（DE4-05）。

## 建议加进语料的句子

「期望」一栏里没提到的地方都应保持原样。

| # | 操作 | 原文 | 期望的结果 | 考什么 |
|---|---|---|---|---|
| 1 | 改错 | Wegen Umbau bleibt das Geschäft bis zum 3. März geschlossen; zuhause arbeiten wir aber weiter. | 原样返回 | 没有错的句子。„wegen Umbau“（不带冠词的名词）是标准用法，„zuhause“ 是允许的写法，„3. März“ 的句点不能丢。 |
| 2 | 改错 | Ich glaube das er hat gesagt das er kommt nicht weil er muss arbeiten. | Ich glaube, dass er gesagt hat, dass er nicht kommt, weil er arbeiten muss. | 三个从句的动词位置加三个逗号。最小改法是 14 个词里改 7 个，用来验证跑偏检查不误报，也验证没有词被删。 |
| 3 | 改错 | Beim schreiben des Berichts ist mir im allgemeinen nichts besonderes aufgefallen, aber die FLC-expression in flc-3 war niedriger als im wildtyp. | Beim Schreiben des Berichts ist mir im Allgemeinen nichts Besonderes aufgefallen, aber die FLC-Expression in flc-3 war niedriger als im Wildtyp. | 名词化和名词的大写要改，`flc-3` 必须保持小写，`FLC` 保持大写。直接检验 DE4-04。 |
| 4 | 改错 | Könnten sie mir bitte sagen, ob sie den Vertrag schon unterschrieben haben? Ich habe ihnen die Unterlagen gestern geschickt. | Könnten Sie mir bitte sagen, ob Sie den Vertrag schon unterschrieben haben? Ich habe Ihnen die Unterlagen gestern geschickt. | 称呼的大写。三处都是只改大小写。 |
| 5 | 改错 | Bitte schicken Sie mir Ihre Email Adresse und die Ergebnisse der DNA Sequenzierung der 10 Tage alten Col-0 Pflanzen. | Bitte schicken Sie mir Ihre E-Mail-Adresse und die Ergebnisse der DNA-Sequenzierung der 10 Tage alten Col-0-Pflanzen. | 复合词的连字符。`Col-0` 和 `10` 要保留；„10 Tage alten“ 不能被改成 „10-Tage-alten“。检验 DE4-05。 |
| 6 | 改错 | Die Strasse war wegen des grossen Schneefalls gesperrt, deshalb sind wir zu fuss gegangen. | Die Strasse war wegen des grossen Schneefalls gesperrt, deshalb sind wir zu Fuss gegangen. | 瑞士写法。只改 „zu Fuss“ 的大写，一个 ß 都不能出现。 |
| 7 | 改错 | Im Jänner haben wir heuer die Sessel im Besprechungszimmer getauscht. | 原样返回 | 奥地利用词（„Jänner“、„heuer“、„Sessel“）不能被换成 „Januar“、„dieses Jahr“、„Stühle“。同一句也可以拿去测润色，期望相同。 |
| 8 | 改错 | Das Buch, dass ich gestern gekauft habe ist spannender als ich dachte. Er sagte: „Das machen wir Morgen“, und ging. | Das Buch, das ich gestern gekauft habe, ist spannender, als ich dachte. Er sagte: „Das machen wir morgen“, und ging. | 关系代词 das 和连词 dass 的区分、关系从句后的逗号、als 从句前的逗号。„…“ 引号和引号后的逗号要保留。„Morgen“→„morgen“ 是只改大小写。 |
| 9 | 语气（友好） | Senden Sie die Unterlagen bis Freitag. Verspätete Einsendungen werden nicht berücksichtigt. | 例如：Könnten Sie mir die Unterlagen bitte bis Freitag schicken? Später eingehende Unterlagen können wir leider nicht mehr berücksichtigen. | 语气变友好，但必须仍然是 Sie，截止日期和「逾期不收」这两个事实不能丢。 |
| 10 | 英译德 | Revenue rose 3.4% to 2.5 billion euros, and the company now has 1,250 employees. "We are very pleased," said the CEO. | Der Umsatz stieg um 3,4 % auf 2,5 Milliarden Euro, und das Unternehmen hat inzwischen 1.250 Beschäftigte. „Wir sind sehr zufrieden“, sagte der CEO. | „billion“ 是 „Milliarden“，不是 „Billionen“（差一千倍）。小数逗号、千位点、百分号前的空格、„…“ 引号、逗号在后引号的外面。 |
| 11 | 英译德 | Hey, are you coming to the party tonight? Bring your sister if you want! | Hey, kommst du heute Abend zur Party? Bring deine Schwester mit, wenn du willst! | 明显的非正式语域，应当用 du，并且全文一致。和 en-de-1 配成一对。 |
| 12 | 改错 | Ich habe gestern den Bericht gelesen und denke das wir müssen noch einige änderungen machen bevor wir es einreichen.（现有的 de-fix-2） | Ich habe gestern den Bericht gelesen und denke, dass wir noch einige Änderungen machen müssen, bevor wir ihn einreichen. | 这条已经在语料里。建议把期望结果写成完整的句子，并把「„müssen“ 必须还在」列为硬性考点。只写考点关键词的话，e4b 这次的输出会被算作大部分通过。 |
