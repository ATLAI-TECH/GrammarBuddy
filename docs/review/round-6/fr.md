# Claire（法语，法国；职业校对兼审稿人）— 多语言复评 Round 6

## 结论

法语上只有 **qwen3-14b** 的改错能用，大约一半条目可以直接 ⏎（35/69 次），而且它从不在原文上留下看不见的破坏。但它照样漏掉法语最典型的难点（`allée`、`j'ai faites`、`payiez`、`finissions`），润色和语气有 2/3 条直接输出了**英语**。qwen3-8b 在润色、语气、翻译上是三个里最好的，改错却有一半条目原样返回。qwen3-4b-2507 什么都改一点，但会改坏东西：把不换行空格全部换成普通空格，把 `n’ira` 改成 `ne ira`，删掉包容性书写，润色时把法语翻成英语。
**按内存推荐：** 8 GB 的机器没有可以放心推荐的模型。4b 只能当「给建议、不能 ⏎ 直接替换」来用，法语的润色和语气要关掉。16 GB 用 14b 做改错和翻译，润色和语气在加上输出语言检查之前改用 8b。24 GB 以上用 14b，同样要有语言检查。法语改错**不该推荐 8b**，法语的任何功能都**不该推荐 4b** 作默认。和第 4 轮的 gemma-4 比：速度和稳定性好了很多（0.1–2.1 秒，没有空输出），14b 的语言质量和 gemma-4-12b 相当；但出现了一个新的、更危险的失败方式：换了语言。

## 我怎么评的，查了什么

**评分标准**（三档，按「条目 × 次」计）：
- **可直接用**：考点里的错误都改了（期望以外的正确改法也算），没有改坏，没有多余的改动。
- **小问题**：没有改坏，但还剩**一处**错误要手改，或者有一处无害但多余的改动、用词稍欠。
- **不能用**：改坏了（引入新错、换了语言、意思变了、丢了保护内容或看不见的字符）；或者原文有错，输出却和原文一样（或者只改了无关的地方）；或者按 ⏎ 后还剩**两处及以上**明显错误。「原样返回」我算不能用，理由是：用户看到「没有改动」会以为文字没有问题，这比改错一处更误导人。

**原始字符核对**（`python3 -I` 只读 `corpus.json` 和三个 `qwen__*.json`，逐条打印 U+00A0、U+202F、U+2019、U+0027、U+0301、U+00B7、U+0153、直引号的码位，以及 `; : ? ! » € % h` 前、`«` 后、数字之间的空格码位；另外用 `unicodedata.is_normalized` 查了每条输出的 NFC 状态）：

| 检查对象 | 结果 |
|---|---|
| fr-r4-1 原文的不换行空格 | 只有 **4 个**（`devis` U+202F `?`、`1` U+202F `400`、`400` U+00A0 `€`、`€` U+00A0 `:`）。我第 4 轮建议里写「五个」是我自己数错了，句子本身给的就是 4 个 |
| fr-r4-1，8b、14b 共 6 次 | 4 个码位、位置全部保留。14b 还改对了 `cher`，和期望逐字节相同 |
| fr-r4-1，4b #0、#1 | **4 个全部变成 U+0020**，`chère` 也没改。屏幕上和原文一模一样，实际有 4 处被改了 |
| fr-r4-1，4b #2 | 留住了 `1` 和 `400` 之间的 U+202F，另外 3 个变成 U+0020。和 #0、#1 在 Markdown 里看起来完全一样，只有码位不同 |
| 机械检查对 4b 的 fr-r4-1 | `protected_missing` **没有报**。`run.py` 的 `PROTECT` 里已经没有任何空格类，`norm()` 又用 `\s+` 把 U+00A0、U+202F 和普通空格当成一样（我验证过 Python 的 `\s` 能匹配这两个字符）。所以「不换行空格被换掉」现在既不会被标成保护项丢失，也不会让「= expected」失败 |
| fr-r4-2 弯撇号 | 8b、14b：3 个 U+2019 全部保留。4b：只剩 2 个，`n’iras` 变成了 `ne ira`，第三个撇号连同省音一起没了 |
| 其他条目新插入的撇号 | 全部跟随原文（原文是 U+0027 的，新加的 `n'avons`、`n'est`、`m'envoyer` 也都是 U+0027） |
| fr-r4-16 原文的分解重音（4 处 `e` + U+0301） | **三个模型 9 次全部输出 NFC**（`é` 合成形式）。14b 被标成「= expected」，但期望里是分解形式，两边实际上并不逐字相同：`norm()` 比较前先做了 NFC |
| fr-r4-11 英译法的空格 | 14b 三次和 4b #1 在千分位用了 **U+202F**（模型自己选的，提示词没有要求），可是 `€` 前、`%` 前、`h` 两侧、`« »` 内侧、`?` 前仍然是 U+0020。8b 和 4b #0、#2 全部是 U+0020。也就是说同一个 `1 400 000 €` 里混着两种空格 |
| en-fr-1、fr-r4-12、fr-r4-13 的英译法 | `« »` 内侧、`? !` 前全部是 U+0020，没有一个不换行空格 |
| fr-r4-8 的中点 U+00B7 | 8b、14b 保留了 4 个。4b #0、#2 只剩 2 个（`étudiant·e·s` 变成 `étudiants`），#1 一个不剩 |
| 思考、空输出、截断 | 207 次法语调用：思考 0 字符，`finish` 全部正常，没有空输出 |

## 统计

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| qwen3-4b-2507 | 12 | 27 | 30 |
| qwen3-8b | 22 | 17 | 30 |
| qwen3-14b | 35 | 19 | 15 |

（23 条 × 3 次 = 69。fr-es-1 在西语文件里，我不评。）

不能用的原因分类：

| 原因（每次只归一类，按表中顺序取第一个符合的） | 4b | 8b | 14b |
|---|---|---|---|
| 换成了英语 | 6（fr-polish-1、fr-r4-14） | 0 | 6（fr-polish-1、fr-r4-15） |
| 改坏：引入新错、丢了看不见的字符、删包容性书写、改了拼写体系 | 15（r4-1、r4-2、r4-7、r4-8、r4-12） | 3（r4-7） | 3（r4-7） |
| 原样返回（屏幕上看和原文相同） | 2（fr-fix-2 #1 #2） | 21（fr-fix-1、r4-1、r4-6、r4-8、r4-9、r4-10、r4-16） | 0 |
| 改了，但剩两处以上错误，或者要求的语气没做到 | 7（fr-fix-2 #0、r4-6、r4-15） | 6（fr-fix-2、r4-17） | 6（r4-6、r4-17） |
| 合计 | 30 | 30 | 15 |

## 逐条评分

| 条目 | 模型 | 次 | 结论 | 说明 |
|---|---|---|---|---|
| fr-fix-1 | 4b | #0–2 | 小问题 | `résultats`、`précédemment` 改了，`montre` 没改成 `montrent`：主语一复数，动词就错了，审稿人一眼能看到 |
| fr-fix-1 | 8b | #0–2 | 不能用 | 原样返回，三处错误一处都没改 |
| fr-fix-1 | 14b | #0–2 | 可直接用 | 三处全改。`a influencé fortement` 没动，对的（语序不算错误） |
| fr-fix-2 | 4b | #0 | 不能用 | 只补了 `n'avons`；`remerci` 没改，`malgré que` 后仍是直陈式。剩两处 |
| fr-fix-2 | 4b | #1、#2 | 不能用 | 原样返回 |
| fr-fix-2 | 8b | #0–2 | 不能用 | 同 4b #0：`Je vous remerci` 留着，语式没改 |
| fr-fix-2 | 14b | #0–2 | 可直接用（有争议） | `Je vous remercie … ; malgré le fait que nous n'avons pas encore reçu …`。换成 `malgré le fait que` 绕开了有争议的 `malgré que`，而 `malgré le fait que` 后面用直陈式是语法书承认的（Grevisse 记录了直陈和虚拟两种）。所以这句话是对的。**有争议**：严格的校对会要求 `bien que nous n'ayons pas`，并且会说「改错不该换词」；我个人可以接受，句子只是略显笨重。`;` 前的空格保住了。这是三轮里第一个在这条上给出语法正确结果的模型 |
| fr-fix-3 | 4b / 8b / 14b | 各 #0–2 | 小问题 | 9 次输出逐字相同：`acheté`、`sais` 改了，**`allé` 没改成 `allée`**。引语里的 `je` 就是 `Elle`。第 4 轮 gemma-4-12b 改对了，这一轮三个模型都没改对。`« »`、`:`、`?` 前的空格（U+0020）都保留 |
| fr-polish-1 | 4b | #0–2 | 不能用 | 输出是英语：`In this article, we'll discuss how plants know when it's time to flower…` |
| fr-polish-1 | 8b | #0–2 | 小问题 | `Dans cet article, nous allons parler de la manière dont les plantes déterminent le moment propice pour fleurir, ce qui constitue un processus essentiel pour leur reproduction.` 语法无误，口语结构都去掉了。但 `pour leur reproduction` 是原文没有的内容（原文是 `pour elles`），`ce qui constitue un processus` 把「这件事很重要」改成了「这是一个过程」。和第 4 轮 e4b 一样，作者得自己收一收 |
| fr-polish-1 | 14b | #0–2 | 不能用 | 英语：`In this article, we will talk about how plants know…`（#2 用 `discuss`） |
| fr-en-1 | 4b | #0–2 | 小问题 | `1,400,000 €`：英语应写 `€1,400,000`，提示词要求按目标语言格式化数字。`the mayor stated` 可以。#2 `investment for our children` 也可以 |
| fr-en-1 | 8b | #0 | 可直接用 | `by 21 votes to 14, for a budget of €1,400,000 … said the mayor.` 准确。`municipal council` 可以（`town council` 更自然，原文看不出规模） |
| fr-en-1 | 8b | #1、#2 | 小问题 | 同 #0，但写成 `1,400,000 €` |
| fr-en-1 | 14b | #0、#1 | 小问题 | `voted … a budget of €1,400,000`：`voter un budget` 的直译（第 4 轮同样的问题，英式议会用语里有人接受，**有争议**，请英语评审复核）；`21 votes to 14` 少了 `by` |
| fr-en-1 | 14b | #2 | 小问题 | 改成了 `for a budget`，直译没了；`21 votes to 14` 仍缺 `by` |
| en-fr-1 | 4b | #0–2 | 小问题 | `« Nous sommes convaincus par les résultats »`：`confident in` 是「对结果有信心」（报告还没发布），`convaincus par` 是「被结果说服」，意思偏了。其余正确 |
| en-fr-1 | 8b | #0–2 | 可直接用 | 和第 4 轮 e4b 逐字相同。空格全部是 U+0020（见 FR4-02，不算模型的错） |
| en-fr-1 | 14b | #0、#1 | 可直接用 | 同 8b |
| en-fr-1 | 14b | #2 | 可直接用 | `Nous avons confiance dans les résultats`，更地道 |
| fr-r4-1 | 4b | #0–2 | 不能用 | `chère` 没改；不换行空格 #0、#1 丢了 4 个，#2 丢了 3 个。用户在屏幕上看到的是「没改动」，实际上原文被悄悄改了 |
| fr-r4-1 | 8b | #0–2 | 不能用 | 原样返回（码位也一样），`c'est trop chère` 没改 |
| fr-r4-1 | 14b | #0–2 | 可直接用 | 和期望逐字节相同，4 个不换行空格码位、位置都对 |
| fr-r4-2 | 4b | #0–2 | 不能用 | `qu’elle ne ira pas`：`à`→`a`、`iras`→`ira` 改对了，但省音没了。`ne ira` 在法语里是错的，必须 `n’ira`。这是改错改出来的新错，机械检查没有报（`n` 是单字母，被 `dropped_words` 跳过） |
| fr-r4-2 | 8b / 14b | 各 #0–2 | 可直接用 | `L’équipe a décidé qu’elle n’irait pas à la réunion.` 和期望（`n’ira`）不同，但主句是过去时，用条件式表示「过去中的将来」是**更规范**的时态配合。**有争议**：最小改法是 `n’ira`，两种都对。3 个 U+2019 全部保留 |
| fr-r4-3 | 全部 | 各 #0–2 | 可直接用 | 9 次都是 `Est-ce que tu as reçu mon message?`：改了 `as`，没补 `?` 前的空格。按我第 4 轮提的规则（没选变体就保持原文），这正是 `expect_alt`。机械检查标成「不等于 expected」，因为 `run.py` 不读 `expect_alt`（见 FR6-08） |
| fr-r4-4 | 全部 | 各 #0–2 | 可直接用 | 9 次都原样返回。两个陷阱（`après que` + 直陈式、`écrites` 的配合）都没上当。第 4 轮担心的过度纠正没有出现 |
| fr-r4-5 | 全部 | 各 #0–2 | 小问题 | 9 次都是 `j'ai fait … corrigées`：被动态的 `corrigées` 改了，`avoir` 加前置直接宾语的 `faites` 三个模型都没改。这是法语改错的基本功 |
| fr-r4-6 | 4b | #0、#1 | 不能用 | `dû`、`ce n'est pas` 改了，`plutôt`（应为 `plus tôt`）和 `sa`（应为 `ça`）没改，剩两处 |
| fr-r4-6 | 4b | #2 | 不能用 | 只改了 `dû`，剩三处 |
| fr-r4-6 | 8b | #0–2 | 不能用 | 原样返回 |
| fr-r4-6 | 14b | #0 | 不能用 | 同 4b #0 |
| fr-r4-6 | 14b | #1、#2 | 不能用 | 只把 `ces` 改成 `ce n'est`；`du`、`plutôt`、`sa` 都留着。补 `ne` 我按第 4 轮的说法算可以接受，但剩下三处 |
| fr-r4-7 | 4b | #0–2 | 不能用 | `cout`→`coût`、`aout`→`août`，却留着 `évènement`，同一句里两套拼写混用；`payez` 没改成 `payiez` |
| fr-r4-7 | 8b | #0–2 | 不能用 | 只把 `cout` 改成 `coût`；`payez` 没改 |
| fr-r4-7 | 14b | #0–2 | 不能用 | 三处 1990 年拼写全部改回传统写法（`coût`、`événement`、`août`），至少统一了；`payez` 没改。改了三处不该改的，漏了唯一该改的 |
| fr-r4-8 | 4b | #0、#2 | 不能用 | `Les étudiants sont invité·e·s`：删了一处包容性书写，句子变成两套写法混用；`leur` 没改 |
| fr-r4-8 | 4b | #1 | 不能用 | 包容性书写全删（`étudiants … invités`），`leur` 没改 |
| fr-r4-8 | 8b | #0–2 | 不能用 | 原样返回，`leur mémoires` 没改 |
| fr-r4-8 | 14b | #0–2 | 可直接用 | 和期望相同，4 个 U+00B7 保留 |
| fr-r4-9 | 4b | #0–2 | 可直接用 | 和期望相同：`lundi 3 mars`、`sœur`、`français et allemand` |
| fr-r4-9 | 8b | #0–2 | 不能用 | 原样返回 |
| fr-r4-9 | 14b | #0 | 小问题 | 大小写都改了，`soeur` 没改成 `sœur`。`soeur` 键盘上很常见，算轻微 |
| fr-r4-9 | 14b | #1、#2 | 可直接用 | 和期望相同 |
| fr-r4-10 | 4b | #0–2 | 可直接用 | 和期望相同：只改了 `ça`，`;` 前没补空格，魁北克词汇和 `25,50 $` 都没动 |
| fr-r4-10 | 8b | #0–2 | 不能用 | 原样返回，`sa inclut` 留着 |
| fr-r4-10 | 14b | #0–2 | 小问题 | `ça` 改了，但在 `semaine` 和 `;` 之间**补了一个空格**（U+0020）。按法国规范这是对的，可这段文字明显是魁北克法语（`courriel`、`fin de semaine`、`stationnement`、`25,50 $`），而且提示词要求保留标点前的空格习惯。同一个模型在 fr-r4-3 的 `?` 前又不补，行为不一致 |
| fr-r4-11 | 4b | #0–2 | 小问题 | `La ville a validé un budget de 1 400 000 euros (augmentation de 3,5 %) le 3 mars à 10h30. « Cela suffit-il ? » a demandé Mme Martin.` 准确。`validé` 不如 `approuvé`/`adopté`；`10h30` 很常见，但规范写法是 `10 h 30`。`»` 后没加逗号、`Mme` 不带点、月份小写，都对 |
| fr-r4-11 | 8b | #0–2 | 可直接用 | `La ville a approuvé un budget de 1 400 000 € (en hausse de 3,5 %) le 3 mars à 10 h 30. « Est-ce suffisant ? » a demandé Mme Martin.` 我给不出更好的译法。空格全部是 U+0020 |
| fr-r4-11 | 14b | #0–2 | 可直接用 | 同 8b，只是 `(hausse de 3,5 %)` 少了 `en`，括号里的新闻体可以接受。千分位用了 U+202F，其余位置是 U+0020 |
| fr-r4-12 | 4b | #0–2 | 不能用 | `peux-tu me envoyer`：漏了省音，必须 `m'envoyer`。新错 |
| fr-r4-12 | 8b | #0–2 | 可直接用 | `Salut, peux-tu m'envoyer le fichier ce soir ? Merci beaucoup !` 用了 `tu`，正确。倒装比口语略正式，没关系 |
| fr-r4-12 | 14b | #0–2 | 小问题（有争议） | `Hey, peux-tu m'envoyer …`：`Hey` 没译。法国年轻人的聊天里确实会写 `Hey`，但翻译应给出 `Salut` |
| fr-r4-13 | 4b | #0–2 | 小问题 | `« Nous sommes convaincus par les résultats. »`：`« »` 保住了（FR4-05 修好了），但 `convaincus par` 意思偏了，同 en-fr-1 |
| fr-r4-13 | 8b | #0–2 | 小问题 | `"Nous sommes confiants dans les résultats."`：译文对，引号却是英文直引号 U+0022，提示词要求的法语引号没有做到 |
| fr-r4-13 | 14b | #0–2 | 可直接用 | 和期望相同 |
| fr-r4-14 | 4b | #0–2 | 不能用 | 整句译成英语，连引语也译了：`The mayor said: « We're not raising taxes this year »…` |
| fr-r4-14 | 8b / 14b | 各 #0–2 | 小问题 | 6 次逐字相同：`Le maire a dit : « On va pas augmenter les impôts cette année », et après il est parti vite fait sans répondre à aucune question.` 引语一个字没动（FR4-15 的担心没发生），`il` 重复去掉了，`aucune question` 改对了。但 `et après`、`vite fait` 这两个最口语的地方没碰，更像改错不像润色 |
| fr-r4-15 | 4b | #0–2 | 不能用 | `Salut, peux-tu me renvoyer …`：只做了倒装，`Salut` 和 `tu` 都还在，根本没变正式 |
| fr-r4-15 | 8b | #0–2 | 可直接用（有争议） | `Bonjour, pouvez-vous me renvoyer le contrat signé avant vendredi ? Merci !` `tu` 全部换成 `vous`，没有混用。`Merci !` 偏随意，期望里的 `Je vous en remercie.` 更正式；放进工作邮件可以直接用 |
| fr-r4-15 | 14b | #0–2 | 不能用 | 英语：`Hello, can you send me back the signed contract before Friday? Thank you!` |
| fr-r4-16 | 4b | #0–2 | 小问题 | `résultats` 改了，`montre` 没改。另外 4 个分解重音被合成成 NFC（看不出来，见 FR6-04） |
| fr-r4-16 | 8b | #0–2 | 不能用 | 两处错都没改，只是重音从分解变成合成。屏幕上就是原样返回 |
| fr-r4-16 | 14b | #0–2 | 可直接用 | 两处都改对。码位上是 NFC，和期望（NFD）并不相同；这属于设计的问题（FR4-09），不算模型的错 |
| fr-r4-17 | 4b | #0–2 | 小问题 | `revienne`、`soit` 改对了，`finissons` 没改成 `finissions`。三个模型里虚拟式改得最好的是最小的这个 |
| fr-r4-17 | 8b / 14b | 各 #0–2 | 不能用 | 只改了 `revienne`；`finissons` 和 `bien qu'il est` 留着，剩两处 |

## 模型排名和推荐

1. **qwen3-14b**：法语上最好。改错 15 条里 8 条三次都可直接用（r4-9 另有两次），从不悄悄破坏不换行空格、弯撇号、中点。失败集中在两类：①法语语法难点（`allée`、`faites`、`payiez`、`finissions` 一个都没改对，`fr-r4-6` 的同音词改不全）；②润色和语气换成英语（fr-polish-1、fr-r4-15，三次都一样）。英译法质量最好，连千分位都自己用了 U+202F。
2. **qwen3-8b**：润色、语气、英译法是三个里最稳的（没有换语言，`tu`/`vous` 都对，r4-11 完美）。可是改错有 7 条（21 次）原样返回，其中有 `c'est trop chère`、`sa inclut` 这种一眼就能看到的错。它几乎不改坏东西，但「什么都不改」本身就是失败。
3. **qwen3-4b-2507**：在几条简单的上表现意外地好（r4-9、r4-10 完全正确，r4-17 改对了两个虚拟式），但它是唯一一个会**改坏**的：不换行空格换成普通空格、`ne ira`、`me envoyer`、删包容性书写、润色时译成英语。

**按内存：**
- **8 GB**：没有可以放心推荐给法语用户的模型。只能用 4b 时：法语只开改错和翻译，并且以「逐处建议、用户确认」的方式显示，不能一键 ⏎ 替换；法语的润色和语气关掉。App 必须先做空格和撇号的还原（FR4-03），否则 4b 会悄悄改掉 Word 稿子里的不换行空格。
- **16 GB**：改错、翻译用 **14b**；润色、语气在加上输出语言检查（FR6-01）之前用 **8b**。
- **24 GB 以上**：**14b**，加语言检查后润色、语气也用它；没有语言检查时同上。
- **不该推荐**：8b 做法语改错；4b 作为法语任何功能的默认值。

**和第 4 轮的 gemma-4 比：**
- **变好**：速度从 9–32 秒降到 0.1–2.1 秒，没有空输出、没有思考。设计目标（改错 2 秒）第一次达到了。第 4 轮 12b 交白卷的 fr-fix-2，这一轮 14b 给出了语法正确的结果。
- **持平**：原来那 6 条上，14b 是 3 条可直接用、2 条小问题、1 条不能用，gemma-4-12b 是 3 / 1 / 2（2 条空输出）。fr-en-1、en-fr-1 的质量和第 4 轮几乎逐字相同。
- **变坏**：fr-fix-3 的 `allée` 第 4 轮 12b 改对了，这一轮三个模型共 9 次没有一次改对。fr-fix-1 第 4 轮两个模型都全改对，这一轮 8b 原样返回、4b 漏了 `montrent`。新出现的「换成英语」比第 4 轮的空输出更危险：空输出至少不会写坏稿子，英语输出按 ⏎ 就把用户的法语段落替换掉了。

## 稳定性

三次结果不完全相同的法语条目：4b 6 条，8b 1 条，14b 5 条。

| 条目 | 模型 | 差异 | 有没有一次对一次错 |
|---|---|---|---|
| fr-en-1 | 8b | #0 `€1,400,000`，#1 #2 `1,400,000 €` | **有**：可直接用 / 小问题 |
| fr-r4-9 | 14b | #0 留了 `soeur`，#1 #2 改成 `sœur` | **有**：小问题 / 可直接用 |
| fr-r4-1 | 4b | #2 留了 1 个 U+202F，#0 #1 一个不留 | 都不能用。**在 Markdown 里三次看起来完全相同**，只有码位不同 |
| fr-r4-11 | 4b | #1 千分位是 U+202F，#0 #2 是 U+0020 | 等级相同，同样只有码位不同 |
| fr-fix-2 | 4b | #0 补了 `n'`，#1 #2 原样 | 都不能用 |
| fr-r4-6 | 4b、14b | 改了几处不同 | 都不能用 |
| fr-r4-8 | 4b | 删掉的中点数量不同 | 都不能用 |
| fr-polish-1 | 14b | `talk about` / `discuss` | 都是英语，都不能用 |
| fr-en-1 | 4b、14b | `in`/`for our children`；`a budget` / `for a budget` | 等级相同 |
| en-fr-1 | 14b | `sommes confiants` / `avons confiance` | 都可直接用 |

结论：**没有一次可直接用、一次不能用的情况**，摇摆只在可直接用和小问题之间（2 条）。所有不能用的失败，包括换成英语，都是三次一致的，说明是系统性的，不是运气（温度 0.2）。要注意的是 4b 有 2 条只在看不见的字符上不稳定，靠读 Markdown 的评审发现不了。

## 和第 4 轮比（问题逐条对照；模型之间的对比见上一节末尾）

| 第 4 轮 | 现状 |
|---|---|
| FR4-01 语料没有 NBSP / `’`；检查测不出 | **语料已补**（r4-1、r4-2）。**检查仍然测不出**，而且比第 4 轮更彻底：`PROTECT` 里已经没有空格类，`norm()` 的 `\s+` 把 NBSP 当普通空格，`’` 不在任何检查里。4b 在 r4-1 丢 4 个 NBSP、在 r4-2 丢 1 个 `’`，0 个标记。见 FR6-03 |
| FR4-02 英译法没有不换行空格 | 未解决。12 条英译法输出里，`? ! :` 前和 `« »` 内侧没有一个 NBSP；14b 只在千分位自己用了 U+202F。提示词没改，我仍然建议用规则处理 |
| FR4-03 空格种类应由程序还原 | 这一轮的数据证明这一步是必要的：4b 会换掉，8b、14b 不会。App 里有没有实现，这份材料看不出来 |
| FR4-04 魁北克 / 缺空格 | r4-3 上三个模型都保持了原文（好）；r4-10 上 14b 在 `;` 前补了空格（不好）。变体设置仍然没有。见 FR6-07 |
| FR4-05 `clean()` 削掉引号 | **已修好**：原文首尾是任何一种成对引号时不削；中间还有同种引号时也不削。r4-13 上 14b 的 `« »` 完整保留 |
| FR4-06 只改大小写被误报 | `run.py` 里没有这条检查，r4-9 没有误报。App 里的规则看不到，无法确认 |
| FR4-07 润色阈值；标点算词 | `tokens()` 不再把独立标点算成词（修好了）。润色的「共有词」阈值 `run.py` 没有实现，无法评估 |
| FR4-08 Diff 显示 | 这一轮不涉及 |
| FR4-09 Unicode 规范化 | **已证实**：三个模型 9/9 把 NFD 输出成 NFC。`run.py` 比较时做了 NFC，所以「= expected」看不出来。写回时要还原，见 FR6-04 |
| FR4-10 思考没关掉 | **已解决**：0 思考、0 空输出 |
| FR4-11 fr-fix-2 期望不可判定 | 仍然没有期望结果。14b 给出了第三种正确答案（`malgré le fait que` + 直陈式），应该加进可接受集合 |
| FR4-12 数字、货币、日期 | 语料已加（r4-11），模型做得好（8b、14b 完美）。`run.py` 对翻译仍然不做数字检查（`check()` 对 translate 跳过 `PROTECT`） |
| FR4-13 1990 拼写 / 包容性书写 | 语料已加，**三个模型全部不及格**：r4-7 的 9 次全都改了 1990 拼写；4b 删包容性书写。提示词没加句子。见 FR6-02、FR6-05 |
| FR4-14 `tu` / `vous` | 这一轮表现好：r4-12 9 次都用了 `tu`，r4-15 的 8b 全换 `vous`。默认规则还没写进提示词，但模型自己判断对了 |
| FR4-15 引语边界 | r4-14 上 8b、14b 引语一字未动。4b 连引语一起译成英语，那是 FR6-01 的问题 |
| FR4-16 法语语料太少 | **已解决**：17 条都加了 |

## 设计和提示词的问题

| ID | P0/P1/P2 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| FR6-01 | P0 | `prompts/polish.txt`、`tone.txt` + `_common.txt`；§6.5；`run.py` 的 `check()` | 法语润色和语气 3 条里，4b 有 2 条、14b 有 2 条输出整段英语，三次都一样（共 12 次）。`_common.txt` 里的 `Reply in the same language as the text; never translate it.` 拼在英文任务说明**后面**，模型没听。没有任何机械检查能发现（4b 的 fr-polish-1 的 `checks` 是 `{}`）。按 ⏎ 后用户的法语段落就被英语替换了 | ①App 在显示前用 `NLLanguageRecognizer` 比较原文和输出的语言，不一致时当作失败：不允许 ⏎，自动重试一次。②提示词里写出具体语言名，放在最前面：`The text is in French. Write your answer in French.`（检测到的语言名填进去）。③`run.py` 加 `wrong_language` 标记并进 summary。④改完重跑这 3 条 + 其他语言所有润色、语气条目 |
| FR6-02 | P1 | `prompts/_common.txt`「the original spelling variety (British stays British)」 | r4-7：9 次全部把 1990 修订拼写改回传统写法（`cout`→`coût` 9/9，`aout`→`août` 6/9，`évènement`→`événement` 3/9），4b 还造成同一句两套拼写混用。同一句里唯一真正的错误 `payez`→`payiez` 0/9。第 4 轮 FR4-13 的担心被证实了 | 检测到法语时加一句：`Keep the spelling system of the original: both traditional and 1990-reform spellings (cout/coût, évènement/événement) are correct; do not change one into the other.` 程序上也可以兜底：维护一张 1990 修订对照表，输出里出现「原文是 A 写法、输出变成 B 写法」的整词替换时自动还原 |
| FR6-03 | P1 | `run.py` 的 `PROTECT`、`norm()`、`dropped_words()`；by-language 报告里「= expected」的说明 | 测试工具对法语看不见的字符是瞎的：①`PROTECT` 没有空格类，4b 在 r4-1 丢掉 4 个 NBSP 没有标记；②`norm()` 用 `\s+` 合并空白、并做 NFC，所以「= expected」实际上是「规范化后相同」，不是说明里写的「逐字相同」（r4-16 的 14b 就是这样被标成相同的）；③`’` 丢失（4b r4-2）不在任何检查里；④Markdown 报告看不出码位，4b 在 r4-1、r4-11 的三次输出看起来一样，实际不一样 | ①加一个 `invisible_changed` 检查：把原文和输出里的 U+00A0、U+202F、U+2009、U+2019、U+0027 和组合重音按顺序抽出来比较，计数报告；②`matches_expect` 改成逐字节比较，另加一个 `matches_expect_normalized`，报告里两个都显示；③Markdown 报告里把不换行空格显示成可见记号（比如 `⍽` 和 `⍿`），否则下一轮评审仍然得自己写脚本 |
| FR6-04 | P1 | §6.4、写回逻辑（FR4-09 的后续） | 已证实：三个模型 9/9 把 NFD 原文输出成 NFC。写回时每个带重音的字都换了码位，Diff 和保护项检查如果不做规范化就会一片红；如果做了规范化，又会悄悄把用户的 NFD 文字改成 NFC | 比较前两边都做 NFC；写回时如果原文整段是 NFD，就把输出转回 NFD（或者至少把没被改动的词按原文码位还原）。设置里不用给选项，文档里写明即可 |
| FR6-05 | P1 | `run.py` 的 `tokens()` 和 `dropped_words()`；§6.4 保护项 | 4b 删掉包容性书写（r4-8：`étudiant·e·s`→`étudiants`、#1 连 `invité·e·s` 也删）没有标记：`tokens()` 的正则把 `·` 当成分隔符，剩下的 `e`、`s` 是单字母，被跳过。同样 `n’ira`→`ne ira` 也因为 `n` 是单字母没报 | `tokens()` 把 U+00B7 和 U+2019 当成词内字符（和 `'`、`-` 一样）。保护项加一条：`\w+·\w+(?:·\w+)?` 的词在输出里必须原样出现 |
| FR6-06 | P1 | `docs/MODELS.md`（法语的推荐说明）；改错面板 | 法语最典型的语法点三个模型都做不到：`allée`（远距离性别配合）0/9，`j'ai faites`（`avoir` + 前置宾语）0/9，`payiez` 0/9、`finissions` 0/9（虚拟式），r4-6 的同音词全部改对 0/9。8b 还有一半条目原样返回。用户如果把「没有改动」理解成「没有错误」，就会把有错的稿子发出去 | ①MODELS.md 里法语一节写明：「本地模型能改拼写、简单的主谓配合和大小写；不能可靠地改过去分词配合、虚拟式、同音词。重要文字请另外校对。」②改错结果是「无改动」时，面板别写「没有发现问题」，写「模型没有提出修改」。③8b 不作为法语改错的推荐 |
| FR6-07 | P1 | §6.1 变体设置；`prompts/_common.txt`（FR4-04 的后续） | 14b 在魁北克文字（r4-10）的 `;` 前补了空格，在 r4-3 的 `?` 前却不补，同一个模型自相矛盾。提示词 `Keep … spacing before punctuation` 对 `;` 没管住 | 仍按 FR4-04：加法语变体（法国 / 加拿大 / 瑞士 / 未指定），未指定时程序在输出后检查：原文标点前没有空格、输出加了的，自动去掉（这一步是纯规则，不需要模型）。原文有空格、输出去掉了的，自动补回 |
| FR6-08 | P2 | `run.py` 的 `check()`；`corpus.json` 的 fr-fix-2 | `expect_alt` 写进了语料但 `run.py` 不读，fr-r4-3 9 次正确结果全部被算成不匹配；fr 的「expect match」统计因此偏低。fr-fix-2 仍然没有期望结果 | `matches_expect` 对 `expect` 和 `expect_alt` 任一相同即算通过。fr-fix-2 加期望集合：`bien que nous n'ayons pas`、`malgré que nous n'ayons pas`、`malgré le fait que nous n'avons pas`（和 `… n'ayons pas`）都通过；`malgré que nous n'avons pas` 不通过 |
| FR6-09 | P2 | 翻译的后处理（FR4-02 的后续） | 英译法的引号和空格仍然靠模型：8b 在 r4-13 输出了直引号 `"…"`；所有英译法的 `? ! : « »` 旁都是 U+0020；14b 的 `1 400 000 €` 里千分位是 U+202F、`€` 前是 U+0020，一个数字两种空格 | 目标语言是法语时，在清洗后加规则：成对的 `"…"`/`“…”` 换成 `« … »`；按 FR4-02 的位置把已有的 U+0020 统一换成用户选的那种不换行空格（默认 U+00A0），也把模型自己用的 U+202F 统一过来。这一步不经过模型，结果稳定 |
| FR6-10 | P2 | `prompts/translate.txt` | 法译英时 4b 和 8b（5/6 次）写出 `1,400,000 €`，货币符号留在法语位置。提示词的 `number formatting` 管住了千分位，没管住货币符号的位置 | 提示词改为 `number and currency formatting (for example €1,400,000 in English, 1 400 000 € in French)`。改完重跑 fr-en-1，确认不会让 14b 在英译法时反而写错 |
| FR6-11 | P2 | `results/summary.md` | 4b 的 summary 写着 `reasoning_off: False`，而说明里写三个模型都是 `reasoning: "off"`。4b-2507 本来就是不思考的版本，0 思考也证实了这一点，但这一行会让读的人以为开关没生效 | summary 里对这种模型写 `reasoning_off: n/a (non-thinking model)`，或者在说明里补一句 |

建议下一轮语料加的法语句子（只列这一轮暴露出来的）：
1. **润色，长一点的书面法语**（考 FR6-01：长段落是不是更容易换语言）：`Nous avons constaté que les résultats obtenus lors de la deuxième série d'essais étaient sensiblement différents de ceux de la première, ce qui nous amène à penser que le protocole n'a pas été appliqué de manière rigoureuse.` 期望：仍是法语，意思不变。
2. **改错，`avoir` 配合再来一条，宾语更近**：`La lettre que tu m'as envoyé est arrivée hier.` 期望：`envoyée`。看模型是只在距离远时漏，还是一律不会。
3. **改错，带 1990 拼写，但没有其他错误**：`Il faut connaitre le cout réel de cet évènement.` 期望：原样返回。用来单独测 FR6-02 的提示词改动。
