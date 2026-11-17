# Lucía（西班牙语）— 多语言复评 Round 6

## 结论

西语上只有 **qwen3-14b** 能用，而且只能用在「改错」和「译成西语、西译英」上，都要先看一眼再放回去。改错时它改得准，不乱改地区用法，可重音、`¿`、*porqué / a ver / hay*、*este aula*、*callaos* 漏得多，有一条还把意思改了；润色时它原样返回，等于没做；有一条翻译把提示词里的 `[12]` 抄进了译文。**qwen3-4b-2507** 改错时从不改坏，但漏掉的错大约有一半，润色时会把西语整段翻成英语，译成西语时语法出错，只能当「抓明显错误」的工具用。**qwen3-8b** 在西语上不该推荐：改错多数时候原样返回，润色改了人物的对白，还把 *billones* 译成 *billion*。

按内存：8 GB 用 4b，只用于改错，润色和翻译不要交给它；16 GB 和 24 GB 以上都用 14b（16 GB 能不能稳定跑 8.4 GB 的模型，这次没有测，见 ES6-11）；8b 无论多少内存都不推荐用于西语。

评分标准（这一轮比第 4 轮写得更细，三个模型用的是同一把尺子）：

- **可直接用**：该改的都改了，没有新错，不看就按 ⏎ 没问题。
- **小问题**：模型没有造出新错，意思也没变，但还留着原文的错（考点改了一半或一半以上），或者有变体、称谓、排版上可以接受的偏差。放回去是安全的，但还得有人过一遍。
- **不能用**：模型造出了新错（含翻译里的正字法错误，因为用翻译的人往往看不出来）；意思变了；输出的语言不对；或者原文有错，考点却改了不到一半（包括原样返回）。

## 统计

按「条目 × 次」计，28 条 × 3 次 = 84。

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| qwen3-4b-2507 | 27 | 22 | 35 |
| qwen3-8b | 19 | 15 | 50 |
| qwen3-14b | 47 | 23 | 14 |

只算 14 条有错的改错（es-fix-1..3、es-r4-1..11，共 42 次）：4b 可直接用 3 / 小问题 20 / 不能用 19；8b 1 / 6 / 35；14b 20 / 11 / 11。四条应当原样返回的句子（voseo、墨西哥用词、raya 对话、*sólo / éste*）三个模型 36 次全部原样返回，这是这一轮最好的消息。

## 逐条评分

| 条目 | 模型 | 次 | 结论 | 说明 |
|---|---|---|---|---|
| es-fix-1 | 4b | #0–2 | 小问题 | 改了 *resultados, ha, floración, había*，**漏了** *muestra → muestran*：*Los resultados del experimento muestra* 主谓不一致，校对会退稿。 |
| es-fix-1 | 8b | #0–2 | 不能用 | 原样返回，5 处错一处没动。 |
| es-fix-1 | 14b | #0–2 | 可直接用 | 5 处全改了，*reportado* 没动（美洲用法，没动是对的）。 |
| es-fix-2 | 4b | #0, #1 | 小问题 | *llegaste*、*dijo* 改了；**没加 `¿`，没加重音**：*Cuando llegaste a la oficina?* |
| es-fix-2 | 4b | #2 | 不能用 | 只改了 *llegaste*，*nadie me dijeron* 留着，4 个考点改了 1 个。 |
| es-fix-2 | 8b | #0–2 | 不能用 | 同 4b #2。 |
| es-fix-2 | 14b | #0–2 | 小问题 | 同 4b #0：*Cuando llegaste a la oficina? … nadie me dijo nada.* 第 4 轮 gemma-4-12b 这一条是全对的。 |
| es-fix-3 | 三个模型 | #0–2 | 小问题 | 9 次输出完全相同：*vengas* 改了，*temas que tenemos que discutirlos* 的复指代词留着。和第 4 轮的 e4b 一样。 |
| es-en-1 | 4b | #0–2 | 不能用 | **`1.400.000 euros` 原样带进英语**，英语读者会读成 1.4 或者以为是排版错误；raya 也留着：*—And who's going to pay for all this? —the mayor asked.* 机械检查没有标出来（ES4-01 仍然存在，见 ES6-03）。 |
| es-en-1 | 8b | #0, #2 | 小问题 | 数字对（*1,400,000*、*3.5%*）；raya 留在英语里；*¿Y quién…?* 的 *Y* 丢了（*Who is going to pay…*），语气轻了一点。 |
| es-en-1 | 8b | #1 | 小问题 | 同上，数字写成 *1.4 million euros*，值是对的，英语也自然；但按数字字符比对的检查会把它当成丢了数字（误报）。 |
| es-en-1 | 14b | #0, #2 | 小问题 | 数字对，译文好（*3.5% more than last year*）；raya 留在英语里。 |
| es-en-1 | 14b | #1 | 小问题 | 同上，而且 raya 的位置错了：*all of this?— asked the mayor*，收尾的 raya 贴在问号后面。比 #0 差。 |
| en-es-1 | 4b | #0–2 | 可直接用 | `¿ ¡` 和重音都对。#0 *por ninguna parte*，#1/#2 *en ningún lugar*，都自然。*pusiste* 是美洲用法（ES4-04）。 |
| en-es-1 | 8b | #0–2 | 不能用 | **开头的 `¡` 漏了**：*No las puedo encontrar en ningún lado!*，而这正是这一条的考点。用这个功能的人多半看不出来。 |
| en-es-1 | 14b | #0–2 | 可直接用 | *¡No puedo encontrarlas en ninguna parte / ningún lugar!* |
| fr-es-1 | 4b | #0–2 | 不能用 | *Le lamentamos informarles que…*：*lamentar* 是及物动词，*Le lamentamos* 不成立，而且 *le* 和 *-les* 单复数自相矛盾。#0/#1 *anulado*，#2 *cancelado*，都可以，但句子开头是错的。 |
| fr-es-1 | 8b | #0–2 | 可直接用 | *Lamentamos informarle que su vuelo fue cancelado debido a condiciones meteorológicas.* *fue cancelado* 是美洲的时态选择，去掉 *las* 可以接受。*informarle que* 的争议同第 4 轮（有争议，西班牙编辑会改成 *de que*）。 |
| fr-es-1 | 14b | #0–2 | 可直接用 | 和第 4 轮 gemma 的输出逐字相同。 |
| es-r4-1 | 4b | #0–2 | 小问题 | 6 个重音改了 5 个，**句首的 *Tu* 没改**。三个模型都没改句首这个 *Tu*，大写的词可能被当成不必动。 |
| es-r4-1 | 8b | #0–2 | 不能用 | 原样返回。 |
| es-r4-1 | 14b | #0 | 小问题 | 改了 *sé, vendrá, tú*；漏了 *Tú, él, sí*（3/6）。 |
| es-r4-1 | 14b | #1, #2 | 小问题 | 漏了 *Tú* 和 *sí*（4/6）。*pero yo sé que si vendrá* 读起来成了「如果他会来」，原文就有这个错，不是模型造的。 |
| es-r4-2 | 4b | #0–2 | 小问题 | *qué, cómo* 改了；*No se*、*decirselo* 没改（2/4）。 |
| es-r4-2 | 8b | #0–2 | 不能用 | 原样返回。 |
| es-r4-2 | 14b | #0–2 | 可直接用 | = expected。 |
| es-r4-3 | 4b | #0–2 | 不能用 | 只改了 *el por que → el por qué*，**改成了另一个错**（名词应当是 *el porqué*）；*porque, haber si, Ahí que* 没动。 |
| es-r4-3 | 8b | #0–2 | 不能用 | 和 4b 逐字相同。 |
| es-r4-3 | 14b | #0–2 | 不能用 | 第一处 *por qué* 改对了；*el por qué* 同上是错的；*haber si*、*Ahí que* 没动（1/4）。这一条三个模型都不行，而且这是西语母语者最常犯的一类错。 |
| es-r4-4 | 4b | #0–2 | 可直接用 | = expected。 |
| es-r4-4 | 8b | #0–2 | 小问题 | *hubo* 改了；*hacen → hacía*，和后面的 *no pasaba* 时态更一致，我认为是对的另一种改法；但 *Habían* 留着（2/3）。 |
| es-r4-4 | 14b | #0, #2 | 可直接用 | = expected。 |
| es-r4-4 | 14b | #1 | 小问题 | *Habían* 留着，其余对。 |
| es-r4-5 | 4b | #0–2 | 小问题 | dequeísmo 改了；*me alegro que*（queísmo）留着。queísmo 在口语里很普遍，但规范写法要 *de*。 |
| es-r4-5 | 8b | #0–2 | 不能用 | 原样返回。 |
| es-r4-5 | 14b | #0–2 | 可直接用 | = expected。 |
| es-r4-6 | 4b | #0–2 | 不能用 | 原样返回，laísmo *la dije* 没改。 |
| es-r4-6 | 8b | #0–2 | 不能用 | 同上。 |
| es-r4-6 | 14b | #0–2 | 可直接用 | *le dije* 改了，*le vi* 保留（可接受的 leísmo），正是期望的。 |
| es-r4-7 | 4b | #0–2 | 不能用 | 原样返回，*Si tendría* 留着。 |
| es-r4-7 | 8b | #1 | 可直接用 | = expected。 |
| es-r4-7 | 8b | #0, #2 | 不能用 | 原样返回。 |
| es-r4-7 | 14b | #0–2 | 可直接用 | = expected。 |
| es-r4-8 | 三个模型 | #0–2 | 不能用 | 9 次都原样返回 *¡Callaros y sentaros!*。这个用法只在西班牙有，口语里极普遍，规范写法是 *callaos, sentaos*。模型很可能根本不知道这是错。 |
| es-r4-9 | 三个模型 | #0–2 | 不能用 | 9 次都原样返回：*y hijos* 没改成 *e hijos*，*este aula* 没改成 *esta aula*。 |
| es-r4-10 | 4b | #0–2 | 不能用 | 原样返回。 |
| es-r4-10 | 8b | #0–2 | 不能用 | 只删了 *?.* 里多余的句点，其余 5 处（呼语逗号、*marzo*、逗号、`¿`、*qué*）都没改。 |
| es-r4-10 | 14b | #0 | 小问题 | *Hola Marta, si no vienes el 3 de marzo, ¿para qué me llamas?* 只差呼语逗号（*Hola, Marta*），这个逗号日常写作里常被省略。 |
| es-r4-10 | 14b | #1, #2 | 不能用 | ***para qué me llamas → para que me llames***：「你打电话给我干什么」变成「好让你给我打电话」，**意思变了**，而且问号前面还是没有 `¿`。差异视图里只有 *qué → que* 和 *llamas → llames* 两个小改动，用户很容易看漏。 |
| es-r4-11 | 4b | #0–2 | 小问题 | 补了 *reunión, señor, Muñoz, año*；**句首 *Manana* 没改**（4/5）。和 es-r4-1 一样，漏的是句首的词。 |
| es-r4-11 | 8b | #0–2 | 不能用 | 原样返回，*el ano pasado* 留着。 |
| es-r4-11 | 14b | #0–2 | 可直接用 | = expected。 |
| es-r4-12 | 三个模型 | #0–2 | 可直接用 | voseo 原样返回。 |
| es-r4-13 | 三个模型 | #0–2 | 可直接用 | *ahorita, celular, reporté, falla, computadora* 原样返回。 |
| es-r4-14 | 三个模型 | #0–2 | 可直接用 | raya 对话、*1.400.000*、*3,5 %* 都原样返回。 |
| es-r4-15 | 三个模型 | #0–2 | 可直接用 | *Sólo… éste* 原样返回。 |
| es-r4-16 | 4b | #0–2 | 不能用 | **润色时把整段译成了英语**：*—I don't know anything about that,» the old man said, … Ask the priest.* 还凭空加了一个 `»`，丢了 *usté* 的口吻。机械检查这一条没有任何标记。 |
| es-r4-16 | 8b | #0–2 | 不能用 | 叙述部分润色得不错（*y después se fue caminando muy despacio hacia su casa, que estaba lejos*），但**第一段对白被改了**：*Pos yo no sé na de eso → No sé nada de eso*。人物的方言被改成标准语，小说编辑绝对不会接受。第二段 *Pregúntele usté al cura* 没动。#0 少了 *casa* 后的逗号，#1/#2 有。 |
| es-r4-16 | 14b | #0–2 | 小问题 | 原样返回。安全，但叙述部分（*después de eso él se fue … para su casa que estaba lejos*）的赘余没有处理，润色等于没做。 |
| es-r4-17 | 三个模型 | #0–2 | 可直接用 | 都是 *1,400 euros*、*2.5 months*；*took* 和 *lasted* 都对。 |
| es-r4-18 | 4b | #0–2 | 可直接用 | *3 trillion*，对。#0/#1 *per capita*，#2 *per inhabitant*，都可以。 |
| es-r4-18 | 8b | #0–2 | 不能用 | ***3 billones → 3 billion***，金额错了一千倍（ES4-02 的假朋友）。数字字符一样，机械检查通过了。 |
| es-r4-18 | 14b | #0–2 | 可直接用 | = expected。 |
| es-r4-19 | 4b | #0–2 | 可直接用 | *un 3,5% hasta 1.400.000,50 dólares*。数字格式是西班牙的；`%` 前没有空格不合 RAE 的建议，但不少报纸也这么写，目标只写了「Spanish」，不算错。 |
| es-r4-19 | 8b | #0–2 | 小问题 | *hasta $1.400.000,50*：西班牙的数字格式配上前置的 `$`。在阿根廷、智利、哥伦比亚 *$* 指本国比索，读者会以为是比索；西班牙的规范是 *1.400.000,50 $* 或写成 *dólares*。 |
| es-r4-19 | 14b | #0–2 | 小问题 | *un 3,5 % hasta los $1.400.000,50*，`%` 前的空格对了，`$` 的问题同 8b。 |
| es-r4-20 | 4b | #0 | 小问题 | *«No firmo eso», dijo el alcalde. «Venga mañana».* 用了西班牙式角引号，标点位置对；没用 raya（按考点算小问题）；*Venga* 少了「回来」的意思，可以接受。 |
| es-r4-20 | 4b | #1 | 不能用 | ***«Venga otro día»***：*tomorrow* 变成了「改天」，意思变了。 |
| es-r4-20 | 4b | #2 | 小问题 | *«No firmaré eso» … «Vuelve mañana».* 用 *tú* 也说得过去，引号同 #0。 |
| es-r4-20 | 8b | #0–2 | 小问题 | *"¡No firmo eso!", dijo el alcalde. "Vuelve / Vuelva mañana."* 凭空加了感叹号，语气变重；直引号；句点放在引号里面，西语应当放在外面。三处都不致命，加起来是小问题的上限。 |
| es-r4-20 | 14b | #0–2 | 可直接用 | *—No firmaré eso —dijo el alcalde—. Vuelva mañana.* raya 的用法完全正确。 |
| es-r4-21 | 4b | #0 | 不能用 | *envíeme*（usted）后面接 *tienes … no dudes*（tú），同一封信里称谓混用；*antes de viernes* 少了冠词。 |
| es-r4-21 | 4b | #1, #2 | 不能用 | 称谓同样混用，而且 *by Friday* 成了 *el viernes*（「在星期五」），期限的意思变了。 |
| es-r4-21 | 8b | #0–2 | 不能用 | 称谓统一用 *usted*，这点好；但 ***para viernes*** 少了冠词，母语者不会这么写，商务邮件发出去很难看。 |
| es-r4-21 | 14b | #0–2 | 小问题 | *Por favor, envíame el contrato firmado para el viernes. Si tienes alguna pregunta, no dudes en llamarme.* 语法全对，通篇用 *tú*。按考点算小问题；给客户的邮件里这个称谓偏随便。 |
| es-r4-22 | 4b | #0–2 | 不能用 | *¿Todos van…? Lleva a tus amigos!*：前一句 *ustedes*，后一句变成单数 *tú*；开头的 `¡` 漏了。 |
| es-r4-22 | 8b | #0–2 | 不能用 | *¿Todos vais…? Traed a vuestros amigos!*：通篇用西班牙的 *vosotros*，前后一致，这点是三个模型里唯一做对的；但开头的 `¡` 漏了。 |
| es-r4-22 | 14b | #0–2 | 不能用 | ***Lleva a tus amigos ¡[12]!***：**把提示词示例里的引用标记 `[12]` 抄进了译文**，`¡` 放错了位置，*ustedes* 和 *tus* 混用。三次一模一样（ES6-01）。 |

## 和第 4 轮比

只有 6 条是两轮都有的（es-fix-1..3、es-en-1、en-es-1、fr-es-1），我先拿这 6 条直接比：

| 条目 | gemma-4-e4b（R4） | qwen3-4b | gemma-4-12b（R4） | qwen3-14b |
|---|---|---|---|---|
| es-fix-1 | 可直接用 | 小问题（漏 *muestran*） | 可直接用 | 可直接用 |
| es-fix-2 | 小问题（漏重音） | 小问题，#2 不能用（漏 `¿` 和重音） | 可直接用 | 小问题（漏 `¿` 和重音） |
| es-fix-3 | 小问题 | 小问题 | 不能用（输出为空） | 小问题 |
| es-en-1 | 小问题（raya） | 不能用（*1.400.000*） | 可直接用（换成了英语引号） | 小问题（raya） |
| en-es-1 | 可直接用 | 可直接用 | 可直接用 | 可直接用 |
| fr-es-1 | 可直接用 | 不能用（*Le lamentamos…*） | 可直接用 | 可直接用 |

- **质量**：在这 6 条上，qwen3-4b 比 gemma-4-e4b 差（三条变差，没有一条变好）；qwen3-14b 和 gemma-4-12b 差不多：es-fix-3 不再输出为空，但 es-fix-2 不再补 `¿` 和重音，es-en-1 不再把 raya 换成英语引号。qwen3-8b 在这 6 条上就比 gemma-4-e4b 差（es-fix-1 原样返回，en-es-1 漏 `¡`）。
- **速度**：这是唯一大幅改进的地方。第 4 轮西语改错要 12–31 秒，这一轮 14b 在 0.4–1.8 秒，4b 在 0.1–0.5 秒，都达到了 §6.6 的 2 秒目标。
- **空输出**：没有了，ES4-08 解决了。
- 新增的 22 条里，14b 是唯一靠得住的：*laísmo / leísmo* 分得清，*Si tuviera*、*decírselo*、*Mañana* 都改了，四条不该动的句子都没动。但三个模型都不认识西班牙的 *callaros*、*e hijos / esta aula*、*porqué / a ver / hay*，这些是西语用户最需要工具帮忙的地方。

总的来说：14b 是「质量和 gemma-4-12b 相当，快了一个数量级以上」；4b 是「比 e4b 快，但质量变差」。

## 稳定性

温度是 0.2（`run.py` 第 50、88 行），所以有些条目三次结果不一样。西语里三次不一样的条目：

| 条目 | 模型 | 差别 | 结论有没有变 |
|---|---|---|---|
| es-fix-2 | 4b | #2 没改 *dijeron* | **变了**：两次小问题，一次不能用 |
| es-r4-4 | 14b | #1 没改 *Habían* | **变了**：两次可直接用，一次小问题 |
| es-r4-7 | 8b | 只有 #1 改了 *tuviera* | **变了**：一次对，两次原样返回 |
| es-r4-10 | 14b | #0 几乎全对；#1/#2 把 *para qué me llamas* 改成 *para que me llames* | **变了，而且最危险**：一次小问题，两次改了意思 |
| es-r4-20 | 4b | #1 *Venga otro día* | **变了**：一次改了意思 |
| es-en-1 | 8b、14b | 8b #1 *1.4 million*；14b #1 raya 位置错 | 没变（都是小问题） |
| es-r4-1 | 14b | #0 多漏了 *él* | 没变（小问题） |
| en-es-1、fr-es-1、es-r4-16、es-r4-18、es-r4-21 | 不同模型 | 用词、逗号、撇号的细小差别 | 没变 |

一次对一次错的有 5 处，14b 有 2 处。最要紧的是 es-r4-10：同一个模型、同一个句子，三次里一次给出正确的 *¿para qué me llamas?*，两次改了意思。用户只会看到其中一次，不知道自己碰上的是哪一次。

## 设计和提示词的问题

先说第 4 轮问题的现状（只说这次的材料能判断的部分）：

| 第 4 轮 | 现状 |
|---|---|
| ES4-01 数字分隔符 | **没解决**。4b 把 *1.400.000 euros* 原样带进了英语，机械检查没有标（见 ES6-03）。 |
| ES4-02 *billón* | **没解决**。8b 译成 *3 billion*，检查通过。 |
| ES4-03 重音的差异显示 | 无法判断（这一轮没有 App 的差异视图）。这一轮反而更需要：14b 在 es-r4-10 把 *qué → que* 改错了，差异只差一个重音。 |
| ES4-04 / ES4-05 变体和称谓 | **没解决**。目标还是只写「Spanish」，结果 es-r4-21、es-r4-22 称谓前后混用，es-r4-19 的 `$` 有歧义（见 ES6-05）。 |
| ES4-06 `¿ ¡` 和大小写检查 | 无法判断（是 App 的检查，不是 `run.py` 的）。 |
| ES4-07 润色时保护 raya 对话 | **没解决**。`polish.txt` 还是只写「direct quotations」，8b 改了对白（见 ES6-07）。 |
| ES4-08 思考导致空输出 | **解决了**。没有一次思考，没有一次空输出。 |
| ES4-09 raya 范围的单元测试 | 在 `qa/model-eval/` 里没看到，有没有写我没有核实。 |
| ES4-10 地区变体 | `_common.txt` 没改，但这一轮四条不该改的句子都没被改，实际效果没问题。建议还是把措辞改掉，因为现在的写法只讲拼写。 |
| ES4-11 翻译时的对话破折号 | **没解决**，而且更严重了：西译英 9 次全部把 raya 留在了英语里（见 ES6-06）。 |
| ES4-12 NFD、ES4-13 无重音输入、ES4-15 语言检测 | 语料加了 es-r4-11（无重音输入），14b 全对。NFD 输入和加泰罗尼亚语短句没有加。 |
| 语气（tone） | 西语还是没有一条语气的条目。 |

新的问题：

| ID | P0/P1/P2 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| ES6-01 | P0 | `translate.txt`、`_common.txt` 里的示例「such as [12]」；`run.py` 的 `protected_missing` | 14b 在 es-r4-22 三次都输出 *Lleva a tus amigos ¡[12]!*，原文里没有 `[12]`，是从提示词示例里抄来的。检查只看「保护项丢了没有」，不看「多出来一个原文没有的保护项」，所以这一条没有被标出来。用户按 ⏎ 就会把一个假引用写进稿子。（zh 文件里也有 33 处 `[12]`，可能大多是原文里本来就有的，我没有逐条看。） | 提示词里不要放具体的示例值，只放这次实际要保护的项（`{PROTECTED}`），或者换成不会被当成正文的说明（「bracketed numeric citation markers」）。检查里加一条反方向的：输出里出现了原文没有的引用标记、标识符、URL，就报警，并且拦住 ⏎。 |
| ES6-02 | P0 | `_common.txt`「never translate it」；§6.5 的输出检查 | 4b 在 es-r4-16（润色）三次都把西语整段译成了英语。summary 里 es 这一行 `dropped words 0`，机械检查完全没发现。用户在 ⏎ 之后会得到一段英文。 | 非翻译操作的输出要检测语言，和原文语言不一致就拦下，并自动重试一次。这项检查很便宜（`NLLanguageRecognizer`），应当在 App 和 `run.py` 里都做。4b 不要用于西语润色。 |
| ES6-03 | P0 | §6.4 翻译的数字比对（ES4-01、ES4-02） | 第 4 轮担心的两种错这一轮都真的出现了，检查都没有标：4b 西译英输出 *1.400.000 euros*（英语里读成 1.4 或排版错误），8b 把 *3 billones* 译成 *3 billion*（差一千倍）。反过来，8b 的 *1.4 million euros* 是对的，按数字字符比对反而会误报。 | 同 ES4-01、ES4-02：按源语言和目标语言的地区把数字解析成数值再比较；*billón / billion / trillion / millardo / mil millones / million* 这类数量词也换算成数值一起比较；比较不了就在面板上提示「请核对数字」。 |
| ES6-04 | P1 | `fix.txt`；`_common.txt`「Keep the original quotation mark style, dashes and spacing before punctuation」 | 改错漏掉的主要是西语特有的正字法：开头的 `¿`（es-fix-2 9 次全漏，es-r4-10 只有 14b #0 补上了）、区别性重音、句首单词（es-r4-1 的 *Tu*、es-r4-11 的 *Manana*，三个模型都漏）。**有争议**：我怀疑「保留原来的标点和间距」被模型理解成「标点不要动」，但这一轮没有对照实验，证明不了。 | 改错时给一句按语言加的提示，例如西语：「Add missing opening ¿ and ¡ and missing written accents; these are spelling errors, not style.」。把「Keep the original quotation mark style…」限定为「when they are correct」，或者只放在润色和翻译的提示词里。改完用这一轮的西语条目对照重跑。 |
| ES6-05 | P1 | `translate.txt` 的 `{TARGET}`；§2.5 菜单（ES4-04、ES4-05） | 目标只写「Spanish」，模型自己挑变体，而且同一句里前后不一致：es-r4-22 4b 用 *ustedes* 又用 *tú*，14b *ustedes* 配 *tus*；es-r4-21 4b *envíeme* 配 *tienes*；es-r4-19 西班牙的数字格式配美洲式的前置 `$`。只有 8b 在 es-r4-22 通篇用了 *vosotros*。 | 同 ES4-04、ES4-05：目标写成具体的变体和称谓（例如「Spanish (Spain), formal *usted*, decimal comma, «» quotes」），面板上给「正式 / 非正式」开关。`run.py` 也按变体跑西语，不要只跑「Spanish」。 |
| ES6-06 | P1 | `translate.txt`（ES4-11） | 西译英 9 次全部把 raya 留在了英语里，14b #1 还把 raya 放错了位置。第 4 轮 gemma-4-12b 会换成英语引号，这一轮三个模型都不会。英语读者会觉得是排版错误。 | 在「quotation marks, question and exclamation marks…」里加上「dialogue punctuation (Spanish and French dialogue dashes become quotation marks in English, and the other way round)」。 |
| ES6-07 | P1 | `polish.txt`、`tone.txt`；§6.1（ES4-07、ES4-09） | 唯一一条测 raya 保护的润色，三个模型都没过：4b 译成了英语，8b 把对白 *Pos yo no sé na de eso* 改成了 *No sé nada de eso*，14b 干脆原样返回。只靠提示词保护对白不够。 | 不要只靠提示词：按 ES4-09 的规则在代码里把对白段落标出来，送给模型之前换成占位符或者用标签包起来，回来以后逐字比对，对白被改了就拦下。提示词同时写明「including dialogue introduced by a dash (—)」。 |
| ES6-08 | P1 | 改错的输出检查；`run.py` 的 `temperature: 0.2` | 改错会悄悄改掉意思，而且结果不稳定：14b 在 es-r4-10 三次里有两次把 *para qué me llamas* 改成 *para que me llames*；4b 在 es-r4-3 把 *el por que* 改成另一个错的 *el por qué*；4b 在 es-r4-20 有一次把 *tomorrow* 译成 *otro día*。这些都是只差一两个字母的改动，现有的检查（删词、保护项、长度）都发现不了。 | 改错和翻译用 `temperature: 0`，至少不让同一个句子每次结果不同；`run.py` 用温度 0 再跑一次，看这些「一次对一次错」的条目会落到哪一边。差异视图里把动词的式和人称变化、*qué/que*、*por qué/porque* 这类改动特别标出来（这也是 ES4-03 的字符级差异）。 |
| ES6-09 | P1 | §2.2 面板对「原样返回」的显示；推荐表 | 8b 在 14 条有错的改错里，有 8 条三次都原样返回（另有一条三次中有两次原样返回）。如果面板把「没有改动」显示成「没有发现问题」，用户会以为稿子是干净的，这比改坏更难察觉。 | 西语不要推荐 8b。面板上「没有改动」要写成「模型没有提出修改」，不要显示一个绿色的对勾。 |
| ES6-10 | P2 | 语料 `corpus.json` | 西班牙特有的用法三个模型全部漏掉（*callaros*、*este aula*、*e hijos*）。语料里还是没有西语语气条目，没有 NFD 输入，没有加泰罗尼亚语短句（ES4-12、ES4-15）。es-fix-1..3 没有「期望的结果」，所以 `= expected` 统计偏低（4b 18/66 里没有算这三条）。 | 补上这几条；给 es-fix-1..3 写上期望结果（第 4 轮报告里有）。 |
| ES6-11 | P2 | `summary.md` | 测试机器是 24 GB，三次运行之后交换区都用了 14.7–17.9 GB，所以这一轮的速度不能代表 8 GB、16 GB 的机器，我按内存给的推荐只是按模型大小推的。4b 那一节写的是 `reasoning_off: False`，和说明里「`reasoning: "off"`」不一致（4b-2507 本来就不思考，结果不受影响，但读的人会糊涂）。 | 在 16 GB（最好也在 8 GB）的机器上实测 14b 和 4b 的加载时间和交换区。summary 里写明「这个模型不支持思考，所以没有发 off」。 |
