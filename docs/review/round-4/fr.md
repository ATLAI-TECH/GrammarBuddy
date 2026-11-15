# Claire（法语，法国；职业校对兼审稿人）— 多语言评审 Round 4

## 结论

两个模型都**还不能**让法语用户「不看就按 ⏎」：gemma-4-e4b 六条都有输出，但只有 2 条可直接用，考到的两个真正的语法难点（`malgré que` 后的虚拟式、引语里 `allée` 的阴性配合）它都漏了；gemma-4-12b 答出来的 4 条质量更好（唯一改对 `allée` 的就是它），但 6 条里有 2 条在 32 秒后交了白卷。所有 12 个输出里没有一个不换行空格，设计稿 §2.5 承诺的「标点前的不换行空格」在这批输出里是 0 次。

## 我查了什么（原始字符）

用 python3 只读打开 `corpus.json` 和两个结果 JSON，逐字符打印了法语条目里所有非字母的非 ASCII 字符，以及 `: ; ? ! » €` 前一个字符、`«` 后一个字符的码位。另外读了 `run.py` 的 `clean()`、`PROTECT`、`words()`。结果：

| 检查对象 | 结果 |
|---|---|
| 语料 fr-fix-2、fr-fix-3、fr-en-1 原文里 `; : ?` 前、`«` 后、`»` 前的空格 | 全部是 U+0020（普通空格）。整份法语语料里 **没有一个** U+00A0 或 U+202F |
| 语料里 `1 400 000 €` | `31 20 34 30 30 20 30 30 30 20 20AC`：千分位和 € 前都是 U+0020 |
| 语料里的撇号（`l'expérience`、`j'ai`、`c'est`、`l'école`） | 全部是 U+0027（直撇号）。没有 U+2019 |
| 两个模型的改错输出（fr-fix-2 e4b、fr-fix-3 两个模型） | 空格全部保持 U+0020，和原文一致。e4b 新插入的 `n'avons` 用的是 U+0027，和原文一致 |
| 两个模型的英译法输出（en-fr-1） | `«` 后、`»` 前、`?` 前都是 **U+0020**。没有任何不换行空格 |
| 两个模型的法译英输出（fr-en-1） | `€1,400,000`，引号是 U+0022 直引号，没有残留的 `«»` 或 NBSP |
| 原文没有的 Markdown 记号 | 法语 12 个输出里没有 |

所以这批数据能证明的只有一件事：**原文是普通空格时，模型不会乱动它**。「原文是不换行空格时模型会不会换掉」这一条，语料根本没有考到（见 FR4-01）。

## 逐条评分

| 条目 | 模型 | 该改的改了吗 | 改坏或多改 | 结论 | 说明 |
|---|---|---|---|---|---|
| fr-fix-1 | e4b | 全改了：`résultats`、`montrent`、`précédemment` | 无 | 可直接用 | `a influencé fortement` 语序略不自然（`a fortement influencé` 更好），但不是错，改错不该动，模型没动是对的。12.4 秒，19 个词，离设计目标 2 秒差 6 倍 |
| fr-fix-1 | 12b | 同上，输出逐字相同 | 无 | 可直接用 | 14.6 秒 |
| fr-fix-2 | e4b | `remercie` 改了，`n'avons` 补了；**语式没改** | 无 | 小问题 | 输出是 `malgré que nous n'avons pas encore reçu`。`malgré que`（规范上本就受批评）和 `bien que` 一样要求虚拟式，最小改法是 `n'ayons pas`，更规范的是 `bien que nous n'ayons pas`。模型改了一半，留下一个审稿人一眼能看到的错。没有改坏任何东西，`;` 前的空格保留了。`remercie pour` 可以接受（`remercier de` 更正式，不算错）。21.7 秒 |
| fr-fix-2 | 12b | 没有输出 | — | 不能用 | 32.3 秒后输出为空，`finish=length`：3942 个字符的思考把 1024 token 用完了。用户等了半分钟什么都没拿到 |
| fr-fix-3 | e4b | `acheté`、`sais` 改了；**`allé` 没改成 `allée`** | 无 | 小问题 | 引语里的 `je` 就是句首的 `Elle`，必须是 `Je suis allée`。这是考点里唯一需要跨出引号看主语的配合，e4b 漏了。`« »`、`:` `?` 前的空格、句号在 `»` 内都保留正确。17.2 秒 |
| fr-fix-3 | 12b | 三处全改：`allée`、`acheté`、`sais` | 无 | 可直接用 | 法语 12 个输出里唯一一个做对难点的。14.1 秒 |
| fr-polish-1 | e4b | 口语结构都改掉了（`on va parler de comment` → `nous allons aborder le mécanisme par lequel`） | 加了原文没有的内容 | 小问题 | 语法无误，但：①`le moment optimal` —— 原文只说「什么时候该开花」，没有说「最优」；②`pour leur cycle de vie` —— 原文是 `pour elles`；③`le mécanisme` 用单数，等于断言只有一个机制；④`revêt une importance capitale` 是套话腔，把 `très important` 拔高了。提示词要求「保持正式程度」，这里从口语直接跳到公文体，考点本身就要求变正式，所以不算违规，但作者看了多半要自己再收一收。我会写：`Cet article explique comment les plantes déterminent le moment de fleurir, une question essentielle pour elles.` 另外这条改动率 69%，按 §6.5 会被判为跑偏（见 FR4-07）。9.3 秒 |
| fr-polish-1 | 12b | 没有输出 | — | 不能用 | 31.6 秒，`finish=length`，思考 4424 字符 |
| fr-en-1（法→英） | e4b | 数字 `€1,400,000` 正确，`« »` 换成了英文引号，逗号按美式放在引号内，`by 21 votes to 14` 正确 | `voted … a budget` 是法语 `voter un budget` 的直译 | 小问题 | 英语通常说 `approved a budget` 或 `voted to approve`。`declared the mayor` 也偏直译（`said the mayor` / `the mayor said` 更自然）。**有争议**：`vote a budget/sum` 在英式议会用语里存在，有人会认为可以接受；我作为法语母语者对英语的判断请英语评审复核。`la maire` 的阴性在英语里丢失，无法避免。`conseil municipal` 译 `city council` 可以（小镇应为 `town council`，原文看不出规模）。12.4 秒 |
| fr-en-1（法→英） | 12b | 输出和 e4b 逐字相同 | 同上 | 小问题 | 23.8 秒，是 e4b 的两倍，结果一样 |
| en-fr-1（英→法） | e4b | `« »`、`»` 后的逗号、`?` 前的空格、`lundi` 小写且不带冠词、`vous` 称谓，全部正确 | 空格的种类不对（都是 U+0020） | 可直接用 | `Le rapport sera publié lundi. « Nous sommes confiants dans les résultats », a déclaré le directeur. Avez-vous des questions ?` 译文准确自然。`a déclaré` 比 `a dit` 更合新闻体。`Nous avons confiance dans les résultats` 更地道一点，但现在的写法没错。放进邮件或聊天可以直接用；放进要排版的稿子，我得手工把 4 个空格换成不换行空格（见 FR4-02）。这是设计没兑现，不算模型的错：提示词只说了 `spacing before punctuation`，没说要不换行。11.8 秒 |
| en-fr-1（英→法） | 12b | 同上 | 同上 | 可直接用 | 只差 `a dit le directeur`，更贴原文的 `said`，同样正确。15.1 秒 |

合计：

| 模型 | 可直接用 | 小问题 | 不能用 |
|---|---|---|---|
| gemma-4-e4b | 2 | 4 | 0 |
| gemma-4-12b | 3 | 1 | 2 |

`fr-es-1`（法→西）归在西语文件里，我不评分。只说源语言这一侧：原文的意思两个模型都完整理解了。

## 模型排名和推荐

1. **语言质量：12b 高于 e4b，但样本只有 4 条。** 两个模型都答了的 4 条里，3 条输出相同或等价，唯一的差别是 fr-fix-3：12b 改对了 `allée`，e4b 没有。12b 交白卷的两条（fr-fix-2、fr-polish-1）恰好是法语里最难的两条（虚拟式、整句重写），所以「12b 在法语难点上更强」这句话目前没有证据，只有一个例子。
2. **可用性：e4b 高于 12b。** 12b 在 6 条里有 2 条等了 32 秒后输出为空。§6.5 会把空输出和截断拦下来，不会写坏稿子，但用户白等。
3. **两个模型都没有做对虚拟式。** e4b 漏了，12b 没答。语料里只有这一处考虚拟式，结论是：这批数据里没有任何证据表明哪个模型能改法语的语式错误。对法语用户来说这是改错工具的基本功。
4. **速度两个都不合格。** e4b 9–22 秒，12b 14–32 秒，对象是 19–29 个词的单句。设计目标（§6.6）是改错 2 秒完成。结果 JSON 里写着选用的是 `enable_thinking=false`，但法语 12 个输出里 12 个都带 1458–4424 字符的思考，也就是这个开关在正式语料上没有生效。fr-en-1 上 12b 用了 e4b 两倍的时间，输出一个字不差。
5. **推荐：**
   - 现在就要给法语用户一个默认值：**e4b**，并在说明里写清楚「会漏掉语式和远距离配合错误，结果要自己看一遍」。它没有改坏任何东西，这一点比改得全更重要。
   - **12b 现在不该推荐**，原因是空输出，不是语言质量。把思考真正关掉（或者把 token 上限放宽并重新计时）后重跑这 6 条，如果 fr-fix-2 和 fr-polish-1 能答出来而且质量和 fr-fix-3 一样，我会改为推荐 12b，多等几秒值得。
   - 翻译（法↔英）两个模型质量相同，选快的。

## 设计和提示词的问题

先回答交给我的四个问题，表格里有对应的条目。

**一、§6.4 把不换行空格和 `« »` 列为保护项，是帮助还是天天误报？**
取决于原文从哪来。原文里没有不换行空格的用户（在浏览器、Slack、备忘录里直接打字的人），这项检查没有东西可查，不会报，也没有帮助。原文里有不换行空格的用户（Word 和 LibreOffice 的法语自动更正会在 `: ; ? !` 前和 `« »` 内侧自动插入 U+00A0；从排好版的稿子、网页复制的文字也是），一段话里通常有 5–10 个；只要模型把它们吐成普通空格，面板底部就会写「8 处保护内容被改动」，而这 8 处在屏幕上**看不出任何区别**。报得对，但对用户是噪音：他没法判断，也不该由他一处处撤回。空格的种类是可以机械确定的，应该由程序自己改回去，而不是告警（FR4-03）。这批语料没有一条带不换行空格的原文，所以两个模型到底会不会换掉，现在不知道（FR4-01）。`« »` 的保护是有用的，这批输出里也都保住了。

**二、语料里的法语原文用普通空格，代表真实用户吗？**
只代表一部分人。真实的法语输入至少有四种，语料只有第一种：①普通空格（macOS 上直接打字）；②不换行空格 + 弯撇号 `’`（Word、LibreOffice、Antidote 处理过的稿子，设计稿 §2.8 把 Word 当重点场景）；③标点前根本不打空格（`Tu viens?`，非常常见；在魁北克这是规范写法）；④用直引号 `"…"` 代替 `« »`。另外语料的撇号全是 U+0027，没有 U+2019，而 Word 里出来的法语几乎每个词组都有 `’`。

**三、改错应不应该顺手把普通空格改成不换行空格？**
不应该。理由：①改错的承诺是「尽量少改」，看不见的改动用户无法复核；②目的地不一定欢迎 NBSP：代码、Markdown 源文件、终端、CSV、LaTeX（那里该用 `~`）、字幕文件、一些网页表单；U+202F 在部分字体里还会显示成方框；③改了之后用户搜索 `mot ?` 搜不到。应该做的是三件事：保留原文已有的种类；模型新插入的空格跟随这段文字已有的种类（原文没有 NBSP 就用 U+0020）；另外提供一个**不经过模型**的独立操作「法语排版」，用规则转换，用户主动选才做（FR4-04）。

**四、翻译成法语时「用目标语言的排版习惯」，模型做到了吗？**
眼睛看：做到了，`« »`、`»` 后的逗号、`?` 前的空格都对。按码位看：没有，4 个空格全是 U+0020，§2.5 写的「标点前的不换行空格」没有兑现。而且这条只测了引号和问号，没有测数字、货币、百分号、时间、日期，这些才是英译法最容易出错的地方（FR4-02、FR4-12）。

| ID | 级别 | 位置 | 问题 | 建议 |
|---|---|---|---|---|
| FR4-01 | P1 | `corpus.json`；`run.py` 的 `PROTECT` 和 `protected_changes` | 法语语料没有一条带 U+00A0 / U+202F / U+2019 的原文，§6.4 这一项等于没测。而且测试脚本即使遇到也测不出来：`PROTECT` 末尾的 `[U+00A0 U+202F]` 匹配到之后会被 `token.strip()` 清成空串然后跳过（Python 的 `strip()` 会去掉这两个字符，我验证过）；并且只判断「结果里有没有」，5 个丢 4 个也算通过 | 加带 NBSP、NNBSP、`’` 的原文（见下节 1、2）。检查改成按位置逐个比对并计数，不要 `strip()`。Swift 里同样注意：`trimmingCharacters(in: .whitespaces)` 和 `Character.isWhitespace` 都把 NBSP 当空白 |
| FR4-02 | P1 | §2.5 倒数第二条；`prompts/translate.txt` | §2.5 承诺「英译法用 `« »` 和标点前的不换行空格」。实测两个模型的 en-fr-1 输出里 `«` 后、`»` 前、`?` 前都是 U+0020。提示词写的是 `spacing before punctuation`，没有提不换行；就算提了，我也不会信模型能稳定输出一个看不见的字符 | 不要靠提示词。AI 翻译的目标语言是法语时，在清洗之后加一步规则：把**已有的** U+0020 换成不换行空格，位置限于 `; : ? ! »` 之前、`«` 之后、数字分组之间、数字和 `€ % $ h` 之间。只替换不插入，所以不会碰 URL 和 `10:30`。设置里给三档：不处理 / 全用 U+00A0（和 Word 一致，建议默认）/ `; ? !` 前和千分位用 U+202F、其余用 U+00A0（Imprimerie nationale 的做法）。系统翻译的输出「照原样显示」，那它出来的是哪种空格要实测并写进文档，否则两个引擎结果不一致 |
| FR4-03 | P1 | §6.4 `¿ ¡ « »` 和不换行空格这一行；§6.1 | 对原文带 NBSP 的用户，模型一换空格就是一排橙色标记，而且改动不可见、用户无从判断。保护的目标是对的，手段（告警 + 用户逐处撤回）不对 | 空格种类和撇号种类（`'` / `’`）由程序在清洗后**自动还原**：输出里和原文对齐的位置恢复原来的码位；新出现的位置跟随原文里占多数的种类。还原之后再做检查，这时还对不上的才标橙。还原成功的不计入「N 处保护内容被改动」 |
| FR4-04 | P1 | §6.1 改错；`prompts/_common.txt`、`fix.txt` | 两句提示词在法语上打架：`_common` 说「保留标点前的空格」，`fix` 说「改正标点」。用户写 `Tu viens?`（没有空格）时该怎么办没有定义。在法国这是排版错误，应补空格；在魁北克（OQLF 规范）`? ! ;` 前不加空格才是对的，补了就是改坏。另外设计稿只有英语的拼写变体，没有法语的地区变体 | 定规则：改错**不改变空格的种类**；缺空格是否补，按法语变体决定（法国、比利时：补；加拿大：`: ` 前和 `« »` 内补，`; ? !` 前不补；没选变体：保持原文）。§2.5 的 ⌘L 菜单和 §6.1 的变体设置里加「法语（法国）/ 法语（加拿大）/ 法语（瑞士）」。把「普通空格 → 不换行空格」做成独立的规则操作「法语排版」，不放进改错 |
| FR4-05 | P1 | §6.3 第三条；`run.py` 的 `clean()` | 「输出首尾多出来的引号去掉」的实现是：输出以 `«` 开头、以 `»` 结尾，而原文不是以 `«…»` 开头结尾，就把首尾各削掉一个字符。英译法时原文首尾是 `"…"`，译文首尾是 `«…»`，这是正确的翻译却会被削掉引号。更糟的是 `« A », dit-il. « B »` 这种首尾各是一段引语的句子，会被削成 `A », dit-il. « B`，引号不成对。法语里以引语开头并结尾的段落很常见 | 只在同时满足两条时才去掉：①原文首尾没有**任何一种**引号（`"` `“”` `«»` 算同一类）；②去掉的那一对是包住整个输出的同一对（中间没有别的 `«` 或 `»`）。语料加一条（见下节 13） |
| FR4-06 | P1 | §6.4「只改了大小写的词（句首除外）」 | 法语最常见的改错之一就是只改大小写：`Je parle Français` → `français`，`Lundi 3 Mars` → `lundi 3 mars`（英语习惯带进来的大写）。按现在的规则，这些正确的修改每一处都会被标成「保护内容被改动」 | 这条规则只用于看起来像记号的词：全大写、大小写混排、带数字或连字符（`FLC`、`flc-3`、`mRNA`）。普通的「首字母大写的词变小写」不算保护项，照常显示为普通改动 |
| FR4-07 | P1 | §6.5 润色、语气：「共有的词不到一半」 | fr-polish-1 上 e4b 的输出是一次正常的润色，改动率 69%，共有的词只有 31%，按这条会被判为异常，⏎ 变成复制。法语从口语改成书面语必然换掉大部分虚词（`on` → `nous`，`c'est` → …，`de comment` → `la manière dont`），这条阈值对法语润色会经常误报。另外 `run.py` 的 `words()` 把标点前带空格的 `;` `?` `:` `«` `»` 各算成一个词，法语的词数被虚增（fr-fix-2 的 23 个「词」里有一个是 `;`） | 润色的阈值降到 25% 左右，或者只比较实词；数词数之前先把独立的标点去掉。跑一遍各语言语料里的全部润色输出，看正常结果的分布再定 |
| FR4-08 | P1 | §4.2 Diff「词级差异」；§6.4 的橙色标记 | 三个法语上的问题：①U+0020 ↔ U+00A0 的变化在词级差异里不存在（两边的词一样），橙色标记无处可标，「逐处撤回」也无从下手；②`allé` → `allée`、`cher` → `chère` 整词替换显示，差一个字母，读的人很难看出哪里变了；③`avons` → `n'avons`、`a-t-il` 这类靠撇号和连字符连起来的形式被当成一个词整体替换，看不出是「加了 `n'`」 | ①空格种类变化单独显示：用一个可见符号（Word 用 `°`，也可以用 `⍽`）加悬停说明；②两个词编辑距离很小时，在词内再做字符级高亮；③法语分词在 `'` `’` 和倒装连字符处断开 |
| FR4-09 | P1 | §6.4、§6.5、Diff；语料 | 没有提到 Unicode 规范化。从 PDF、macOS 文件名、某些网页复制的法语，重音字母可能是分解形式（`e` + U+0301）。模型几乎总是输出合成形式（`é`）。逐字符比较时每个带重音的词都算「被改」：差异视图一片红，改错的 40% 阈值被触发，而屏幕上两边一模一样。法语几乎每句都有重音 | 比较前两边都做 NFC；写回时保持原文的形式，或者统一成 NFC 并在文档里说明。语料加一条分解形式的原文（见下节 16） |
| FR4-10 | P1 | 测试方法；`run.py`（`max_tokens=1024`，`thinking_variant`） | JSON 里记录选用的是 `enable_thinking=false`，但法语 12 个输出全部带思考（1458–4424 字符）。探测时 e4b 的思考是 0 字符，正式跑的时候不是，说明探测句不能代表正式语料。12b 因此在 fr-fix-2 和 fr-polish-1 上用完 token，输出为空。结论「12b 在法语上如何」只基于 4 条 | 找到真正能关掉思考的方式后重跑；或者至少把上限提高到不会截断，分别记录思考时间和回答时间。在此之前不要用这批数据给 12b 下结论 |
| FR4-11 | P1 | `corpus.json` 的 fr-fix-2 考点；§6.1「不换词」 | 考点写的是「négation 'n'avons pas' / subjonctif après 'bien que'」，没有说哪个结果算通过。`malgré que` 本身有争议：Académie 不接受，实际用法里很常见。**两种看法**：一种认为改错不该换词，保留 `malgré que`、只把语式改成 `n'ayons`；另一种（我本人校稿时的做法）认为应该换成 `bien que`。两种都要求虚拟式，这一点没有争议 | 把期望结果写成集合：通过 = `bien que nous n'ayons pas` 或 `malgré que nous n'ayons pas`；`n'avons pas` = 不通过。所有语料条目都应该有这样可判定的期望结果 |
| FR4-12 | P1 | `corpus.json` 的 en-fr-1；§6.4 末段翻译的数字检查 | 英译法只测了引号和问号。没测的才是容易错的：`$1,400,000` / `3.5%` / `10:30 a.m.` / `March 3` → `1 400 000 $`、`3,5 %`、`10 h 30`、`le 3 mars`；千分位空格如果是普通空格，数字会在行尾被拆成两半，这比 `?` 掉到下一行严重得多。另外 §6.4 说翻译时「数字去掉分隔符后比较」：法语的分隔符是空格，要去掉 U+0020、U+00A0、U+202F、U+2009 四种；`run.py` 现在的正则把 `1 400 000` 拆成 `1`、`400`、`000` 三个数，`1 400 000` 变成 `1 000 400` 查不出来 | 语料加带数字、货币、百分比、时间、日期的英译法（见下节 11）。数字识别要认「数字 + 空格 + 三位数字」的分组，四种空格都算分隔符。单位符号列表加 `€ $ £`。法语里 `3,5 %` 中间那个空格如果只是种类变了，不要报成「数字被改」 |
| FR4-13 | P2 | `prompts/_common.txt`「the original spelling variety (British stays British)」 | 只举了英语的例子。法语有 1990 年拼写修订：`évènement / événement`、`cout / coût`、`aout / août`、`connaitre / connaître` 两种都正确，改错不该往任何一边统一。还有包容性书写（`étudiant·e·s`），改错既不该删也不该加，中间点 U+00B7 也不能丢。这批语料没有考到，模型怎么做不知道 | 检测到法语时在提示词里加一句：保留原文的拼写体系（传统或 1990 修订）和包容性书写，不增不删。语料加两条（见下节 7、8）。加之前先测一下会不会让模型思考得更久 |
| FR4-14 | P2 | `prompts/translate.txt`；§2.5 | 译成法语时 `you` 是 `tu` 还是 `vous` 没有规定。en-fr-1 里模型选了 `vous`，合适，但那是正式语境。聊天消息译成 `vous` 会很怪。性别同理：`I went` 是 `allé` 还是 `allée` 模型只能猜，fr-fix-3 里 e4b 就猜错了 | 默认 `vous`；原文明显是口语（`hey`、缩写、直呼其名）时用 `tu`；面板里给一个就地切换。语料加一条口语的英译法（见下节 12） |
| FR4-15 | P2 | §6.1「润色和语气不改直接引语里的文字（成对引号内，以及…法语里对话破折号引出的话）」 | 法语的引语边界不能机械确定：①短的插入语留在引号内不另外闭合（`« Je viens, dit-il, dans une heure. »`），`dit-il` 是叙述者的话；②对话用破折号时没有结束标记（`— Tu viens ? demanda-t-elle.`）；③多段引语每段开头重复一个 `«`（guillemet de suite），不成对 | 检查时容忍不成对的 `«`；破折号对话按「到段末」算引语，宁可多保护；文档里写明这是近似。语料加一条带引语的法语润色（见下节 14） |
| FR4-16 | P2 | 语料整体 | 法语只有 3 条改错、1 条润色，没有语气，没有「本来就对、不该动」的句子，没有魁北克法语，没有最典型的法语错误（`avoir` 助动词的过去分词配合、同音词 `a/à`、`ou/où`、`ces/ses/c'est`、`dû/du`）。也没有容易被模型**过度纠正**的正确句子 | 见下节 |

## 建议加进语料的句子

方括号里的码位表示那个位置的实际字符，录入时请用真实字符。

1. **改错，原文带不换行空格**（考 FR4-01、FR4-03）
   原文：`Avez-vous reçu le devis[U+202F]? Le montant est de 1[U+202F]400[U+00A0]€[U+00A0]: c'est trop chère.`
   期望：只把 `chère` 改成 `cher`；五个不换行空格的码位和位置都不变。

2. **改错，原文是弯撇号**
   原文：`L’équipe à décidé qu’elle n’iras pas à la réunion.`
   期望：`L’équipe a décidé qu’elle n’ira pas à la réunion.` 三个 U+2019 都保留，不变成 U+0027。

3. **改错，标点前没有空格**（考 FR4-04）
   原文：`Est-ce que tu a reçu mon message?`
   期望（法国）：`Est-ce que tu as reçu mon message ?`，补的是普通空格。期望（加拿大，或没选变体）：`Est-ce que tu as reçu mon message?`

4. **改错，本来就对，不该动**（两个陷阱：`après que` 后用直陈式是正确的，模型常误改成虚拟式；过去分词配合是对的）
   原文：`Après qu'il est parti, nous avons relu les lettres que j'avais écrites la veille, bien qu'il fût déjà tard.`
   期望：原样返回。

5. **改错，`avoir` 助动词的过去分词配合**
   原文：`Les erreurs que j'ai fait dans le rapport ont été corrigé par ma collègue.`
   期望：`Les erreurs que j'ai faites dans le rapport ont été corrigées par ma collègue.`

6. **改错，同音词，口语否定不该被「升级」**
   原文：`Il a du partir plutôt que prévu, sa m'étonne, ces pas son genre.`
   期望：`Il a dû partir plus tôt que prévu, ça m'étonne, c'est pas son genre.`
   **有争议**：`c'est pas` 省略 `ne` 是口语，不是拼写错误。一种看法是改错应保留；另一种是应补成 `ce n'est pas`。我认为保留才符合「不改语气」，补上的算小问题，不算错。

7. **改错，1990 修订拼写要保留**（考 FR4-13）
   原文：`Nous connaissons le cout de cet évènement, mais il faut que vous payez avant le mois d'aout.`
   期望：只把 `payez` 改成 `payiez`；`cout`、`évènement`、`aout` 不动。

8. **改错，包容性书写要保留**
   原文：`Les étudiant·e·s sont invité·e·s à rendre leur mémoires avant vendredi.`
   期望：只把 `leur` 改成 `leurs`；三处 `·`（U+00B7）保留。

9. **改错，只改大小写和连字**（考 FR4-06：这些改动不该被标成保护项）
   原文：`Nous nous retrouverons Lundi 3 Mars ; ma soeur parle Français et Allemand.`
   期望：`Nous nous retrouverons lundi 3 mars ; ma sœur parle français et allemand.`

10. **改错，魁北克法语**
    原文：`Je vous envoie le courriel en fin de semaine; ça coûte 25,50 $ et sa inclut le stationnement.`
    期望：只把 `sa` 改成 `ça`。`;` 前不补空格，`courriel`、`fin de semaine`、`stationnement`、`25,50 $` 都不动。

11. **英译法，数字、货币、百分比、时间、日期**（考 FR4-02、FR4-12）
    原文：`The city approved a budget of €1,400,000 (up 3.5%) on March 3 at 10:30 a.m. "Is that enough?" asked Ms. Martin.`
    期望：`La ville a approuvé le 3 mars, à 10 h 30, un budget de 1 400 000 € (en hausse de 3,5 %). « Est-ce suffisant ? » a demandé Mme Martin.`
    要检查：千分位、`€` 前、`%` 前、`h` 两侧、`?` 前、`« »` 内侧都是不换行空格；引语以 `?` 结尾时 `»` 后不加逗号；月份小写；`Mme` 不带句点。

12. **英译法，口语，应该用 `tu`**（考 FR4-14）
    原文：`Hey, can you send me the file tonight? Thanks a lot!`
    期望：`Salut, tu peux m'envoyer le fichier ce soir ? Merci beaucoup !`

13. **英译法，整段就是一句引语**（考 FR4-05）
    原文：`"We are confident in the results."`
    期望：`« Nous sommes confiants dans les résultats. »`，首尾的 `« »` 必须还在。

14. **润色，引语必须逐字保留**（考 FR4-15）
    原文：`Le maire il a dit : « On va pas augmenter les impôts cette année », et après il est parti vite fait sans répondre à aucune questions.`
    期望：`Le maire a déclaré : « On va pas augmenter les impôts cette année », puis il est parti précipitamment sans répondre à aucune question.` 引号里的 `On va pas` 一个字都不能动。

15. **语气，口语改正式**（法语现在没有语气测试）
    原文：`Salut, tu peux me renvoyer le contrat signé avant vendredi ? Merci !`
    期望：`Bonjour, pourriez-vous me renvoyer le contrat signé avant vendredi ? Je vous en remercie.` 要检查 `tu` 全部换成 `vous`，没有残留的混用。

16. **改错，重音是分解形式**（考 FR4-09）
    原文：`Les re[U+0301]sultat de l'expe[U+0301]rience montre que la tempe[U+0301]rature a augmente[U+0301].`
    期望：只有 `résultats` 和 `montrent` 两处显示为改动；差异视图和保护项检查都不把其余带重音的词算作改动。

17. **改错，虚拟式（再来一条，因为这次没有一个模型做对）**
    原文：`Il faut que nous finissons le rapport avant que le directeur revient, bien qu'il est déjà tard.`
    期望：`Il faut que nous finissions le rapport avant que le directeur revienne, bien qu'il soit déjà tard.`
