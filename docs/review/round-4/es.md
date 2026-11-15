# Lucía（西班牙语）— 多语言评审 Round 4

## 结论

gemma-4-12b 在西语上质量够用（6 条里 5 条可以不看就放回去），但有一条改错因为思考把 1024 个 token 用光而输出为空；gemma-4-e4b 没有改坏任何东西，却漏掉了三处该改的（疑问词重音、赘余代词、译成英语时的 raya），只能当「帮我抓大错」的工具，不能当校对。

样本很小：只有 3 句改错、3 句翻译，没有一句西语润色或语气，下面的结论只对这 6 条负责。

## 逐条评分

| 条目 | 模型 | 该改的改了吗 | 改坏或多改 | 结论 | 说明 |
|---|---|---|---|---|---|
| es-fix-1 | e4b | 全改了：*resultados, muestran, ha influido, floración, había* | 无 | 可直接用 | *reportado* 是美洲用法（西班牙会写 *señalado / indicado*），模型没有动，这是对的。12.4 秒，对 18 个词的句子太慢。 |
| es-fix-1 | 12b | 全改了，和 e4b 逐字相同 | 无 | 可直接用 | 18.8 秒。 |
| es-fix-2 | e4b | 部分：加了 *¿*，*llegastes → llegaste*，*dijeron → dijo*；**漏了重音**，输出是 *¿Cuando llegaste a la oficina?* | 无 | 小问题 | 留下的是正字法错误（疑问词 *cuándo* 必须带重音）。危险在于用户看到 *¿* 加上了，会以为这个词已经处理完。14 秒。 |
| es-fix-2 | 12b | 全改了：*¿Cuándo llegaste a la oficina? … nadie me dijo nada.* | 无 | 可直接用 | 18 秒。 |
| es-fix-3 | e4b | 部分：*vienes → vengas* 改了；**漏了** *discutirlos*（关系从句里的复指代词，规范写法是 *temas que tenemos que discutir*） | 无 | 小问题 | 结果比原文好，没有引入新错，但校对会退稿。15.8 秒。 |
| es-fix-3 | 12b | 没有输出 | 输出为空（`finish=length`，思考 3885 字符，31.3 秒） | 不能用 | 等了半分钟什么都没有。按 §6.5 会被拦住，不会写坏稿子，但用户白等。原因见 ES4-08。 |
| es-en-1 | e4b | 数字对：*1,400,000*、*3.5%*（去掉了 % 前的空格，英语正该如此） | **保留了 raya**：*—And who is going to pay for all this? —asked the mayor.* 英语不这样标对话 | 小问题 | 意思准确，*a 3.5% increase over last year* 自然。但对话标点是西语的，英语读者会觉得是排版错误。提示词要求用目标语言的标点，模型没做到。16 秒。 |
| es-en-1 | 12b | 数字对；raya 换成了英语引号：*"And who is going to pay for all this?" asked the mayor.* | 无 | 可直接用 | 用的是直引号 `"`，不是弯引号，可以接受。*alcaldesa → mayor* 丢了性别，英语里没有办法，不算错。15.5 秒。 |
| en-es-1 | e4b | *¿Dónde pusiste las llaves? ¡No las encuentro por ninguna parte!* `¿ ¡` 和重音都对 | 无 | 可直接用 | 0.44 秒，没有思考。*pusiste* 是美洲的时态选择；西班牙半岛对刚发生的事会说 *¿Dónde has puesto las llaves?*。不算错，是变体问题（ES4-04）。 |
| en-es-1 | 12b | *¿Dónde pusiste las llaves? ¡No las encuentro por ningún lado!* | 无 | 可直接用 | 8.5 秒。*por ningún lado* 和 *por ninguna parte* 都自然。同样是 *pusiste*。 |
| fr-es-1 | e4b | *Lamentamos informarle que su vuelo ha sido cancelado debido a las condiciones meteorológicas.* 准确，*vous → usted* 正确 | 无 | 可直接用 | 0.58 秒。**有争议**：*informarle que*（不带 *de*）是美洲的主流用法，RAE 认可；西班牙的规范写法是 *informarle de que*，西班牙的编辑会改。没有法语句法的痕迹，看不出经过英语中转。 |
| fr-es-1 | 12b | 和 e4b 逐字相同 | 无 | 可直接用 | 9.2 秒。同上。 |

合计：

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| gemma-4-e4b | 3 | 3 | 0 |
| gemma-4-12b | 5 | 0 | 1 |

## 模型排名和推荐

1. **gemma-4-12b**：推荐给用西语改错的人，前提是修掉空输出（ES4-08）。凡是有输出的 5 条都没有可挑的地方：重音加了，raya 换成了英语引号，没有多改一个词。
2. **gemma-4-e4b**：不推荐用来做西语改错。它在这 6 条里从不改坏，但 3 句改错漏了 2 处，而且漏的正是西语用户最需要工具帮忙的两类（区别性重音、代词）。用来翻译成西语可以推荐：两句都对，不到 1 秒。

速度和质量的取舍：

- 翻译成西语：两个模型的结果几乎相同，e4b 0.4–0.6 秒，12b 8–9 秒。用 e4b。
- 改错：两个模型都在思考，12–31 秒，离 §6.6 的「完成 2 秒」差一个数量级。在都这么慢的前提下，多等 4–6 秒换来 12b 的完整改正是值得的。如果关掉思考后 e4b 能回到 1 秒左右，需要重新跑西语改错再判断，现在的数据说明不了关掉思考后的质量。
- 西译英：两个模型都是 16 秒左右，12b 的结果更好，没有理由选 e4b。

两个模型译成西语时都偏向美洲用法（*pusiste*、*informarle que*）。目标只写「Spanish」时，西班牙的用户拿到的是拉美口吻的译文。

## 设计和提示词的问题

| ID | P0/P1/P2 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| ES4-01 | P0 | §6.4 翻译的数字比对 | 「去掉分隔符后比数字」查不出西语和英语之间最危险的错误：千分位和小数点互换。*1.400 euros* 被原样译成 *1.400 euros*（英语读者读成 1.4），去掉分隔符两边都是 `1400`，通过。*3,5 %* 译成 *35%* 也通过。这项检查只能发现整个数字丢失。另外同一个写法在不同地区意思不同：西班牙、阿根廷、智利、哥伦比亚用 *1.400,5*，墨西哥、中美洲、秘鲁用 *1,400.5*，所以墨西哥稿子里的 *1.400* 是 1.4。 | 按源语言和目标语言的地区把数字解析成数值再比较，不要只比数字字符。判不出分隔符角色时（恰好一个分隔符后跟三位数字，如 *1.400*）在面板里提示「请确认这个数字」。源语言的地区取自「我的语言」里的变体。 |
| ES4-02 | P1 | §6.4 翻译的数字比对 | 用词写的数量完全不在检查范围内，而西语有一个经典的假朋友：*un billón* 是 10¹²，英语 *billion* 是 10⁹；*mil millones* 才是 *billion*。*3 billones de euros → 3 billion euros* 数字一样，通过，金额错了一千倍。日期 *14/11/2026* 译成美式 *11/14/2026* 是对的，译成 *November 14, 2026* 也对，但后者会被报「缺了数字 11」。 | 检查里加一张小词表：*billón / billion / trillion / millardo / mil millones* 出现时提示用户核对。日期和时间从数字比对里排除，或者按日期解析。语料加一句（见下）。 |
| ES4-03 | P1 | §4.2 差异算法；§2.2 面板 | 词级差异下，只差一个重音符号的改动看不出来。es-fix-2 里两个模型的差异视图几乎一样：e4b 是 *Cuando → ¿Cuando*，12b 是 *Cuando → ¿Cuándo*，统计里都是「changed 19% of 16 words」，说明 `¿` 是和词粘在一起算的。用户看到整个词被替换，要逐字母对比才知道重音加了没有。*a → á* 在小字号下本来就难认，*el / él*、*si / sí*、*tu / tú* 更是如此。 | 三处改动：`¿ ¡` 单独作为一个差异单元，不和后面的词合并；被替换的一对词如果只差一两个字符，在词内再做字符级标记，把变了的那个字母加重显示；VoiceOver 朗读时说出「加了重音：cuándo」，否则听起来两个词一样。 |
| ES4-04 | P1 | §2.5 ⌘L 菜单；`translate.txt` 的 `{TARGET}` | 设计稿已经说地区变体各算一项，但只举了英语的例子，这次测试的目标也只写了「Spanish」，结果两个模型都给出美洲时态和用法。西语的变体不只影响用词，还决定：*vosotros / ustedes*，*has puesto / pusiste*，*informar de que / informar que*，小数点和千分位（ES4-01），引号（西班牙出版用 *« »*，墨西哥多用 *“ ”*），阿根廷的 *vos*。 | 菜单里至少给三项：西班牙语（西班牙）、西班牙语（墨西哥）、西班牙语（拉丁美洲，通用）；阿根廷（voseo）可以放到 0.2。引导里选了西语就问一次地区，按系统地区预选。提示词里把变体写成具体要求，不要只写地区名，例如西班牙：*vosotros*、近过去用现在完成时、小数用逗号、引号用 *« »*。系统翻译支持哪些西语变体我没有核实，需要实测后在菜单里标注。 |
| ES4-05 | P1 | §2.5；§7.6 | 称谓和地区是两个独立的选择。英语 *you* 译成西语有五种可能：*tú、usted、vosotros、ustedes、vos*。en-es-1 两个模型都选了 *tú*，这一句合适；换成商务邮件就不一定。设计稿只在 §7.6 写了「系统翻译不能控制称谓，面板里注明」，AI 翻译时也没有给用户选。 | 目标语言有敬称区分时，面板上给一个「正式 / 非正式」开关，写进提示词，按语言对记住。语料加一句英译西的商务邮件，期望 *usted*。 |
| ES4-06 | P1 | §6.4「`¿ ¡`」和「只改了大小写的词」 | 这两项会对正确的西语改错报警。(1) es-fix-2 原文没有 `¿`，两个模型都补上了，这正是考点；如果检查是「`¿ ¡` 有没有变」，这处正确改动会被标成橙色，⏎ 变成复制。漏写开头的 `¿ ¡` 是西语里最常见的错误之一，等于每天误报。(2) 西语的星期、月份、语言名、国籍形容词小写，*Lunes → lunes*、*Español → español* 是标准改错，会被「只改了大小写」拦下。(3)「句首除外」要把 `¿`、`¡`、`—` 后面的第一个词也算作句首，否则 *—¿y quién… → —¿Y quién…* 被拦。 | 改错时：`¿ ¡` 只在**被删掉**时报警；新增的 `¿ ¡` 如果后面有配对的 `? !` 就放行。大小写检查对西语放过星期、月份等固定词表，或者只检查全大写和大小写混合的记号（`FLC`、`Col-0`、`pH`），普通单词首字母的变化不报。 |
| ES4-07 | P1 | §6.1 引语保护；`polish.txt`、`tone.txt` | 设计稿说润色和语气不改 raya 引出的对话，但两个提示词只写了「direct quotations」，没有提对话破折号，模型不会把 *—¿Y quién va a pagar?* 当成引语。语料里也没有任何西语润色或语气的条目，这条规则完全没有被测到。 | 提示词改成「direct quotations, including dialogue introduced by a dash (—) in Spanish or French」。语料加一条带 raya 的西语润色（见下）。 |
| ES4-08 | P1 | `run.py`（`max_tokens=1024`）；§6.5；§6.6 | es-fix-3 上 12b 思考了 3885 个字符，把 1024 个 token 用完，正文为空，用户等 31 秒得到一句「输出被截断」。15 个词的句子不该这样。这次测试里西语改错每一条都在思考，12–31 秒；§6.6 的目标是 2 秒。 | 改错操作关掉思考，或者把思考和正文的 token 上限分开算。输出为空且 `finish=length` 时自动不带思考重试一次，不要直接把失败交给用户。关掉思考后重跑西语三句，再决定推荐哪个模型。 |
| ES4-09 | P1 | §6.1 / §6.4 引语标记的实现 | 「一段 raya 到哪里结束」不能只找下一个 raya。规则应当是：(1) 只有**段首**是 `—` 的段落才是对话；段落中间成对的 raya 是插入语（*La alcaldesa —que llevaba dos años en el cargo— no contestó*），不是引语。(2) 段首 raya 之后是人物的话，到下一个「前有空格、后面紧贴文字」的 raya 为止，那里开始叙述者的插话（*—preguntó la alcaldesa*）。(3) 插话由「紧贴前一个词、后面是标点或空格」的 raya 结束（*—dijo—. Mañana…*），之后回到人物的话，直到段末。(4) 插话没有用 raya 收尾时，按正字法规则，到段末都是叙述。语料里的 es-en-1 正是这种情况：*El presupuesto asciende a 1.400.000 euros…* 按规则是叙述者的话，但很多作者会漏掉收尾的 raya，它也可能是市长接着说的。 | 按上面四条逐段判断，靠 raya 两侧有没有空格区分开头和收尾。第 (4) 种情况把后面的句子标成「可能是引语」（多保护比少保护便宜，它只影响差异视图里的记号）。输入时把 `–`、`--`、行首的 `- ` 也认作 raya，因为很多人键盘上打不出 `—`。续段开头的 `»` 也算引语继续。给这个函数写单元测试，用下面语料里的句子。 |
| ES4-10 | P1 | `_common.txt` | 「keep the original spelling variety (British stays British)」只说了拼写，只举了英语。西语的地区差别主要在语法和用词：*vos tenés*、*ustedes saben*、*ahorita*、*celular*、*reportar*，以及西班牙可接受的 leísmo（*A Juan le vi ayer*）。提示词没有告诉模型这些不是错。这次 *reportado* 没被动，但只有一个例子，不能说明模型不会把 *vos sabés* 改成 *tú sabes*。 | 改成「keep the original regional variety of spelling, grammar and vocabulary (British stays British; Argentine *vos* stays *vos*)」。语料加两句不该被改的拉美西语（见下）。 |
| ES4-11 | P1 | `translate.txt` | 列举目标语言习惯时写了引号、问号叹号、标点前的空格、数字，没有写对话破折号。e4b 把 raya 原样带进了英语。反方向也一样：英语小说对话译成西语应当用 raya，提示词没有说。 | 括号里加上「dialogue punctuation (dashes or quotation marks)」。语料加一句英译西的对话（见下）。 |
| ES4-12 | P2 | §4.2 差异；§6.4；§6.5 | Unicode 规范化。从 PDF 或 macOS 文件名复制来的西语，*á* 和 *ñ* 常是「字母 + 组合符号」（NFD），模型输出是合成字符（NFC）。不做规范化的话，每个带重音的词都显示为被改动，改错的 40% 上限和保护词表也会误报。 | 比较之前把两边都规范化成 NFC；UTF-16 偏移仍然按原文算。写回时保持原文的形式，或者明确统一成 NFC。语料加一条 NFD 的输入。 |
| ES4-13 | P2 | §6.5 改错的跑偏上限 | 用英语键盘打的西语整段没有重音和 ñ（*Manana voy a la reunion con el senor Munoz*）。全部补上是正确的改错，改动比例可能超过 40%。 | 只差附加符号的改动在计算比例时不算，或者减半。 |
| ES4-14 | P2 | §2.5 翻译前合并换行 | 西语对话每一句是一段，行首是 `—`。合并硬换行时，如果只认「列表符号、数字加点、缩进」，以 raya 开头的行会被并进上一段，对话就毁了。用 `- ` 打对话的人还会被当成 Markdown 列表。 | 行首是 `—`、`–` 的行不合并。 |
| ES4-15 | P2 | §2.5 语言检测 | 没有重音的短西语句子，`NLLanguageRecognizer` 容易和葡萄牙语、加泰罗尼亚语、加利西亚语混淆，而西班牙有不少用户同时写这几种语言。我没有实测，只是提醒。 | 语料里加一条无重音的短句和一条加泰罗尼亚语短句，看检测结果；「我的语言」里有的语言优先（设计稿已有这条，确认对第 1、2 种也生效）。 |
| ES4-16 | P2 | §6.4 数字和单位 | *3,5 %*：RAE 要求数字和 `%` 之间有空格（最好是不换行空格），很多报纸不加。改错时模型加上或去掉这个空格都说得过去，现在的检查会把它算作「数字后的单位变了」。提示词说保留标点前的空格，所以预期是不动；这点和 RAE 相反，但对工具来说是稳妥的选择。 | 保持现状，在文档里写明「改错不调整 % 前的空格」。译成西语时由变体决定加不加（西班牙加）。 |

## 建议加进语料的句子

三句改错只覆盖了：数的一致、*a / ha*、漏重音、*-stes*、*nadie + 复数*、虚拟式、复指代词。缺的典型错误如下，每句给出原文和期望结果。

改错，应该改的：

| 考点 | 原文 | 期望 |
|---|---|---|
| 区别性重音 *tú / él / sí / sé / más* | *Tu sabes que el no quiere venir, pero yo se que si vendra si se lo pides tu.* | *Tú sabes que él no quiere venir, pero yo sé que sí vendrá si se lo pides tú.* |
| 间接疑问句里的重音 | *No se que hacer ni como decirselo.* | *No sé qué hacer ni cómo decírselo.* |
| *porque / por qué / porqué*，*haber / a ver*，*hay / ahí* | *No entiendo porque no vino; haber si mañana me explica el por que. Ahí que preguntarle.* | *No entiendo por qué no vino; a ver si mañana me explica el porqué. Hay que preguntarle.* |
| 无人称 *haber* 和 *hacer* | *Habían muchas personas en la sala y hubieron varios problemas; hacen dos años que no pasaba.* | *Había muchas personas en la sala y hubo varios problemas; hace dos años que no pasaba.* |
| dequeísmo 和 queísmo | *Pienso de que tienes razón, y me alegro que hayas venido.* | *Pienso que tienes razón, y me alegro de que hayas venido.* |
| laísmo（要改）和可接受的 leísmo（不改） | *A María la dije que a Juan le vi ayer en el mercado.* | *A María le dije que a Juan le vi ayer en el mercado.*（*le vi* 保留；改成 *lo vi* 算多改） |
| 条件式误用 | *Si tendría más tiempo, iría contigo.* | *Si tuviera más tiempo, iría contigo.* |
| 复数命令式 | *¡Callaros y sentaros de una vez!* | *¡Callaos y sentaos de una vez!* |
| *y → e*，*este aula* | *Padres y hijos se reunieron en este aula.* | *Padres e hijos se reunieron en esta aula.* |
| 标点：呼语逗号、`¿` 只包疑问部分、问号后多余的句点、月份小写 | *Hola Marta, si no vienes el 3 de Marzo para que me llamas?.* | *Hola, Marta, si no vienes el 3 de marzo, ¿para qué me llamas?* |
| 英语键盘打的西语（*año* 不能留成 *ano*） | *Manana voy a la reunion con el senor Munoz; el ano pasado no pude ir.* | *Mañana voy a la reunión con el señor Muñoz; el año pasado no pude ir.* |

改错，应该原样返回的：

| 考点 | 原文（期望：不变） |
|---|---|
| 阿根廷 voseo | *Vos sabés que te quiero. ¿Venís mañana o preferís que te llame?* |
| 墨西哥用词 | *Ahorita te marco al celular; ya reporté la falla de la computadora.* |
| 正确的 raya 对话和数字 | *—No pienso firmar —dijo la alcaldesa—. El presupuesto supera los 1.400.000 euros, un 3,5 % más que el año pasado.* |
| *solo* 和指示代词（**有争议**：RAE 2010 起建议不加重音，2023 年说明作者认为有歧义时可以加；两种写法都不该被改） | *Sólo quiero éste; aquel no me gusta.* |

润色（测 §6.1 的 raya 保护，期望：两段对话里的话逐字不变，只润色叙述部分）：

> *—Pos yo no sé na de eso —dijo el viejo, y después de eso él se fue caminando muy despacio para su casa que estaba lejos—. Pregúntele usté al cura.*

单元测试（ES4-09，raya 的范围；不需要模型）：

| 输入 | 引语部分 |
|---|---|
| *—¿Y quién va a pagar todo esto? —preguntó la alcaldesa.* | *¿Y quién va a pagar todo esto?* |
| *—No lo sé —respondió—. Mañana lo vemos.* | *No lo sé* 和 *Mañana lo vemos.* |
| *—¿Y quién va a pagar todo esto? —preguntó la alcaldesa. El presupuesto asciende a 1.400.000 euros.* | 第一句确定；*El presupuesto…* 标为「可能是引语」 |
| *La alcaldesa —que llevaba dos años en el cargo— no contestó.* | 无（插入语） |

翻译：

| 考点 | 原文 | 期望 |
|---|---|---|
| 西译英，千分位歧义 | *La obra costó 1.400 euros y duró 2,5 meses.* | *The work cost 1,400 euros and took 2.5 months.*（出现 *1.400* 就是错） |
| 西译英，*billón* | *La deuda supera los 3 billones de euros, unos 65.000 euros por habitante.* | *The debt exceeds 3 trillion euros, about 65,000 euros per inhabitant.* |
| 英译西（西班牙），数字、`%`、日期 | *Sales rose 3.5% to $1,400,000.50 on March 3, 2026.* | *Las ventas aumentaron un 3,5 % hasta los 1.400.000,50 dólares el 3 de marzo de 2026.*（墨西哥变体：*3.5 %*、*1,400,000.50 dólares*） |
| 英译西，对话 | *"I'm not signing that," said the mayor. "Come back tomorrow."* | *—No pienso firmar eso —dijo la alcaldesa—. Vuelva mañana.*（*mayor* 性别不明，*alcalde / alcaldesa* 都接受；用引号而不用 raya 算小问题） |
| 英译西，商务邮件的称谓 | *Please send me the signed contract by Friday. If you have any questions, feel free to call me.* | *Le ruego que me envíe el contrato firmado antes del viernes. Si tiene alguna pregunta, no dude en llamarme.*（出现 *tú* 的形式算小问题） |
| 英译西，复数 *you* 的地区差别 | *Are you all coming to the party tonight? Bring your friends!* | 西班牙：*¿Venís todos a la fiesta esta noche? ¡Traed a vuestros amigos!* 拉美：*¿Vienen todos a la fiesta esta noche? ¡Traigan a sus amigos!* |
