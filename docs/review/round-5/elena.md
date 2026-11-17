# Elena Ruiz — 原型试用 Round 5

> 西班牙记者兼译者，西英双语，偶尔处理法语。Pages、Safari 里处理上千词的稿子。人物配置是 MacBook Pro M2 16 GB、macOS 15；实测在这台 M5 Pro 24 GB、macOS 26 上做，速度按这台说。界面英文。QA 目录 `/tmp/gbqa/elena`，截图在 `shots/elena/`。

## 结论（评分 6/10；一句话：系统翻译我已经想每天用了，AI 翻译现在不敢用）

系统翻译这条路很扎实：852 词的稿子一次翻完，十几个数字全部按英语习惯换对了（1.400 millones → 1.4 billion，3,5 % → 3.5%，298.412 → 298,412），西语改错 10 处全对，人名、引号、数字一个没碰。AI 翻译却恰好在我最在意的地方出错：把 «1.400 millones» 译成 **"1.400 million euros"**（英语读者会读成 140 万，差了一千倍），⏎ 一下就插进稿子，对照视图把整篇译文在每一段下面重复一遍，而且我在面板里试一次 AI 翻译，它就悄悄变成了以后的默认。修好这三点我会给 8 分。

## 我的任务和过程

### 任务 0：第一次打开（引导）

1. `--launch --fresh` → 引导第 1 步，默认是 English / Chinese, Simplified（取的是这台机器的系统语言；在我自己的 Mac 上应该会是西班牙语）。`01-start-0.png`
2. 按说明不点下拉框，先试 `set:gb_languages=es,en` → `02-set-langs.png`：界面还是 English / Chinese，**Continue 变灰**，`state.json` 里 `myLanguages` 变成 `[]`。原因是 `set:` 只能写字符串，而语言列表是数组，所以 `set:` 改不了语言。界面没刷新，也没有任何提示说为什么不能继续（E5-12）。
3. 改用 `defaults write atlai.GrammarBuddy.qa.elena gb_languages -array es en`（只改自己实例的设置域），重启实例（不加 `--fresh`）→ `04-langs-relaunch.png`：Spanish / English，「System translation for this pair is installed」。
   - 过程中出了一次事故：上一条被放到后台的重启命令又启动了一个实例，**两个实例同时盯着同一个 QA 目录**，命令被另一个吃掉，脚本一直等。只用 `kill <pid>` 关了这两个自己的实例再重来。这是我操作的问题，不算 App 的问题。
4. 第 2 步「Try translating」，示例是英文（第 2 种语言），选中 → `hotkey:translate`。第一次面板说「No selected text was found」，输入框里还有莫名的「oc i」：引导窗口当时不是 key window（其他评审的实例在抢前台），快捷键被当成了别的 App 的。先 `focus` 再试就好了 → `07-try-translate-1.png`：**English → Spanish，「Nuestros resultados muestran que este método funciona mejor que el anterior en la mayoría de los casos.」** 方向对、译文对，不到 1 秒。
   - 但底栏写「Can't confirm this place is editable, so ⏎ copies」，⌘⏎ 要确认「Formatting may be lost」。这是引导自己的纯文本框，这两句话让我一开始就犯嘀咕（E5-05）。第二次 ⌘⏎ 时提示「The original app is no longer in front. Copy only」，这是因为别的实例抢了前台，环境问题，不计。
5. 第 3 步权限：显示「Allowed」。第 4 步选「Use a model on this Mac」→ 「LM Studio connected」「Qwen3 14B (loaded) (recommended)」→ 「Use this model」直接进第 5 步。`11-step4.png` `12-local.png` 这一步很清楚，两张卡片各写了代价，我一眼就懂。
6. 第 5 步「Try Fix」：英文示例，说明文字写 **「This is plain text, so ⏎ replaces」**。选中 → `hotkey:fix` → 约 15 秒出结果，4 处全对（Their→There、reason→reasons、work→works、then→than）。但底栏写 **「Replacing here would lose formatting, so ⏎ copies」**，按 ⏎ 果然只是复制，「Copied. The original is unchanged」。`14-tryfix-1.png` 引导刚说完 ⏎ 是替换，面板就做了另一件事（E5-05）。
7. Done → `onboardingDone: true`。从打开到第一次成功翻译：选语言、Continue、选中、⌃⌘T，**4 步**（不算 `set:` 的弯路）。

### 任务 1：Pages 里的西语新闻译成英语（`simulate:pages`）

1. `simulate:pages` → `20-pages.png`：**Spanish → English**，方向对；系统翻译：
   「The City Council approved yesterday the new budget, which amounts to **1.4 billion euros**. / "We're not going to raise taxes," said the mayor.」
   数字换算对，«» 换成了英语的引号，对照视图一段原文一段译文，很好读。⏎ 是「insert below」，底栏说明「The translation goes below the original, so its formatting stays」——这正是我在 Pages 里想要的。
   但下面有一行橙色「# Numbers differ from the original: 1.400」。我核了一下，1.4 billion 是对的，这条提示是误报（E5-08）。
2. `panel:aiTranslate` 换 AI 翻译（qwen3-14b，思考 2 秒，约 20 秒）→ `21-pages-ai.png`：
   「The City Council approved yesterday the new budget, which amounts to **1.400 million euros**. / **«We are not going to raise taxes,»** said the mayor.」
   - **数字错了**：英语里 1.400 million 是 1.4 million。同一行橙色提示和系统翻译时一模一样，我分不出哪个是真错（E5-01）。
   - 英语里留着 «»，逗号还放在 » 里面（E5-07）。
   - **对照视图坏了**：整段译文（两段）出现在第 1 段原文下面，又在第 2 段原文下面重复一次（E5-02）。
3. `⌘D` 切到「Translation」视图 → `22-pages-ai-translation.png`，再按 ⏎ → `events.log`：`insertBelow: ... 1.400 million euros ...`，小条「Inserted below the original. ⌘Z to undo (QA simulation)」。**错的数字一下就进了我的稿子，没有任何确认。**
4. 重来一次（`simulate:pages` → `aiTranslate` → `retry`）还是「1.400 million euros」，可以稳定复现 → `24-pages-ai-retry.png`。

### 任务 2：856 词长稿，系统翻译和 AI 翻译

自己写了一篇巴利亚多利德市议会预算报道：16 段，5264 字符，852 词，含十几个西语格式的数字、«» 引语、四行对话破折号（`—¿De dónde salen esos 40 millones? —preguntó.`）、带重音和连字符的人名。

1. `simulate:{… Pages … op:translate …}` → `30-long-sys.png`：**没有走系统翻译，直接显示「This text is longer than the AI can handle at once…」。** 原因：任务 1 里我在面板上换过一次 AI 翻译，这个选择被存成了默认（设置里的「Translate with AI」也被打开了）。我只是想对比一次，结果下一篇长稿就被挡住了（E5-03）。
   这个界面还有两个问题（E5-04）：
   - 按钮写「Process only the first **20** paragraph(s)」，可我的稿子只有 16 段；它把空行也算成了段。实际处理的是 10 段 / 443 词。也没有说「到哪一句为止」。
   - 说明写「Translation isn't limited this way (system translation takes up to 20,000 characters)」，可我**正在翻译**，却没有一个「改用系统翻译」的按钮，只能自己去右上角找。
2. `panel:sysTranslate` → `31-long-sys-progress.png`「Translating 16 paragraphs…」→ 十几秒内全部完成 → `32-long-sys-done.png`。对照视图逐段配对，很好用。译文逐条核对见下面「模型结果」。数字：14 个数字全部按英语格式换对，提示只标出 1.400（它和 1.4 billion 之间换了量级，标出来也算合理）。
   - 问题出在**对话**：`—De la actualización del catastro… —respondió Benítez—. Está todo en el anexo tres.` → `"The updating of the cadastre and the fight against tax fraud," Benítez replied. It's all in Annex Three.` 后半句引语**丢了引号，变成了叙述**。下一段对话也一样。对记者来说这是把话安错了人（E5-06）。
   - 面板一直是 480 宽，852 词要滚很久；设计里说段落多时用 720 × 560（E5-10）。
3. `panel:aiTranslate` → 又是「too long」→ `panel:first=20` → `34-long-ai-running.png`（流式输出）→ 约 65 秒（思考 21 秒）→ `35-long-ai-done.png`：顶部橙色「Only the first 20 paragraph(s) were processed; the result can only be copied」，⏎ 是 copy，⌘⏎ unavailable，这些都对。
   - 但对照视图同样把**整篇 443 词译文在每一段原文下面重复**，10 段就是 10 遍（E5-02）。
   - 内容错误：「terminó pasadas las once de la noche」→「ended **after midnight**」（事实错误）。「acusó … de «maquillar» las cifras」→「accused the ruling team of «cosmetic» figures」（语义乱了）。英语里留着 «» 和对话破折号（E5-07）。

### 任务 3：英译西（Safari 里的英文新闻，只读）

原文：`The minister said the deficit reached $2.5 billion in 2025, or 3.1% of GDP. "Are we going to cut pensions? Absolutely not!" she told reporters on March 4. Sánchez's office declined to comment.`

1. 系统翻译 → `40-en-es-sys.png`：English → Spanish，方向对。「…alcanzó los **2.500 millones de dólares** en 2025, es decir, el **3,1 %** del PIB. "**¿**Vamos a recortar las pensiones? **¡**Absolutamente no!" **Dijo** a los periodistas el 4 de marzo.」数字和 ¿ ¡ 都对；用的是直引号而不是 «»，引语后的「Dijo」不该大写。提示「Numbers differ: 2.5」又是误报。
2. AI 翻译 → `41-en-es-ai.png`：「«¿Vamos a recortar pensiones? ¡Absolutamente no!», le dijo a los reporteros」——引号和小写都对，比系统翻译更像西班牙报纸。但「**3.1%**」保留了英语的小数点，西语应为 3,1 %。这一次数字提示标出了「3.1」，**是真的抓到了错**，值得表扬。
3. 两边都译成「El ministro」，原文后面有「she」，应为「la ministra」。

### 任务 4：法译英（这台机器没有法语包）

原文：`Le gouvernement a annoncé une enveloppe de 1,2 milliard d'euros pour la rénovation des écoles. « C'est un premier pas », a déclaré la ministre de l'Éducation, Élisabeth Moreau, lors d'une conférence de presse à Lyon.`

1. 系统翻译 → `50-fr-sys.png`：**French → Spanish**（按规则，其他语言译成第 1 种），「The first French → Spanish translation needs a one-time system language download.」两个按钮「Download…」「Use AI translation」。说明清楚，有退路，我很满意。
2. `panel:target=en` → 还是需要下载（法→英也没装），界面同上。`events.log` 里**没有新的播报**，VoiceOver 用户听不到「需要下载」（E5-09）。
3. 「Use AI translation」（`panel:aiTranslate`）→ `52-fr-en-ai.png`：「The government announced a 1.2 billion euro fund for school renovations. "It's a first step," said Education Minister Élisabeth Moreau during a press conference in Lyon.」完全正确，引号也换成了英语的。
4. 再选一段法语 → 又是 French → Spanish：临时改的目标只用一次，符合设计。面板菜单里有「记住」（代码里有，按规定没点下拉框）。不过「la mairie de Bordeaux」→「La municipalidad de Burdeos」，西班牙会说「el Ayuntamiento」。

### 任务 5：西语改错（漏了 ¿ 和重音）

原文：`Que piensas hacer manana? El alcalde dijo que no habia dinero, pero la oposicion no le creyo. Segun el informe, el gasto aumento un 3,5 % y alcanzo 1.400 millones de euros. «Nadie nos explico de donde salen esas cifras», dijo Iñigo Arrizabalaga.`

`60-es-fix.png`：10 处修改，**全部正确**：¿Qué、mañana、había、oposición、creyó、Según、aumentó、alcanzó、explicó、dónde。数字、«»、人名一个没动。思考 4 秒，30 秒内出结果。⏎ 是复制（Pages 是富文本），⌘⏎ 替换，说明清楚。这是我会每天用的功能。
唯一的小遗憾：「explicó」「dónde」在引语里面，设计说引语内的改动要带一个引号记号，现在没有（E5-11）。

### 任务 6（补充）：短文本和语言检测

`Real Madrid, 2 - Barça, 1` → `71-ambiguous.png`：「This text is short or its language isn't clear. Which language is it?」默认 Spanish，蓝色 Translate 按钮。`panel:source=en` 后按 ⏎ → English → Spanish，照原样输出。行为正确，不会瞎猜。`Sin comentarios.` 能正确识别为西语。

设置 → Languages（`80-settings-lang.png`）：Spanish / English、「Add a language」、「Translate with AI」开关（被我在面板上那一下打开了）、「Join hard line breaks」。

## 模型结果

| # | 原文 | 输出 | 对不对 | 敢不敢直接用 |
|---|---|---|---|---|
| 1 | …asciende a 1.400 millones de euros. «No vamos a subir los impuestos», dijo la alcaldesa.（系统） | …amounts to 1.4 billion euros. "We're not going to raise taxes," said the mayor. | 对。「approved yesterday the new budget」语序生硬 | 敢，改一下语序 |
| 2 | 同上（AI，两次结果一样） | …amounts to **1.400 million euros**. «We are not going to raise taxes,» said the mayor. | **错**：数字差一千倍；英语里不该用 «» | 不敢 |
| 3 | 852 词长稿（系统） | 14 个数字全对；人名带重音保留；但两处对话后半句丢了引号；「la alcaldesa … aseguró」→「**he** assured」；「La regidora」→「The councilor」；「sus cálculos」（工会）→「**his** calculations」；「acusó de «maquillar»」→「of "makeup" the figures」；「superar un periodo de alegaciones」→「exceed a period of allegations」 | 数字可靠，但性别和引语归属有错 | 只敢当初稿，每处引语都要对原文 |
| 4 | 长稿前 10 段（AI） | 数字全对（€1.4 billion）、文笔比系统好；但「pasadas las once de la noche」→「**after midnight**」；«cosmetic» figures；保留 «» 和 — | 有事实错误 | 不敢 |
| 5 | $2.5 billion … 3.1% … "Are we going to cut pensions? Absolutely not!"（系统，英→西） | 2.500 millones de dólares … 3,1 % … "¿…? ¡…!" **Dijo** … | 基本对；直引号；「Dijo」不该大写；「El ministro」应为「la ministra」 | 敢，改两处 |
| 6 | 同上（AI） | «¿…? ¡…!», le dijo … **3.1%** | 引号对；小数点没换（提示抓到了） | 改了数字才敢 |
| 7 | 法语 1,2 milliard d'euros…（AI，法→英） | 1.2 billion euro fund … "It's a first step," said Education Minister Élisabeth Moreau… | 全对 | 敢 |
| 8 | 法语 850 millions d'euros, en hausse de 2,8 %（AI，法→西） | La municipalidad de Burdeos … 850 millones de euros, en aumento del 2,8 % | 数字对；用词偏拉美 | 敢 |
| 9 | 西语改错（漏 ¿ 和重音） | 10 处全对，数字、引号、人名不动 | 对 | 敢 |
| 10 | 英文示例改错（引导） | 4 处全对 | 对 | 敢 |

速度（M5 Pro 24 GB，另有 4 位评审共用 LM Studio；我的 M2 16 GB 跑 qwen3-14b 会更慢，内存也紧）：系统翻译短句不到 1 秒、852 词十几秒；AI 改错 42 词约 20–30 秒；AI 翻译 443 词约 65 秒（其中思考 21 秒）。

## 优点

1. **系统翻译处理长文很可靠**：852 词一次完成，「Translating 16 paragraphs…」让我知道它在做什么，对照视图一段原文一段译文，正是我核稿时要的样子。
2. **数字本地化做得好**：系统翻译把西语的千位点、小数逗号、«millones»→«billion» 全部换对；AI 把 3.1% 留成英语格式时，数字提示真的抓到了。
3. **翻译方向按规则走，而且看得见**：西→英、英→西、法→西都对，顶部始终写「Spanish → English」。短文本不瞎猜，先问「Which language is it?」。
4. **缺语言包时有退路**：「needs a one-time system language download」加「Download…」「Use AI translation」两个按钮，不会卡死。
5. **西语改错很准，而且守规矩**：¿ 和 10 处重音全改对，没碰数字、«» 和人名。逐处取舍、「10/10 accepted」一目了然。
6. **Pages 里翻译默认「插入到原文下方」**，并说明原因「formatting stays」；只处理前几段时自动降为只能复制、⌘⏎ 灰掉，规则清楚。
7. 引导第 4 步两张卡片把代价写成一句话（「Text stays on this Mac, free / Uses a few GB of memory」），一眼就能选。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 | 截图 |
|---|---|---|---|---|---|
| E5-01 | P0 | AI 翻译 + 数字检查 + ⏎ | `simulate:pages` → `panel:aiTranslate`：「1.400 millones de euros」→「**1.400 million euros**」（英语读作 140 万），两次都一样。⏎ 直接「insert below」，没有确认。数字提示只是一行橙字，而且对系统翻译正确的「1.4 billion」也显示同样的提示，没法分辨真错和误报。 | ① AI 翻译的提示词写明「数字按目标语言格式书写，量级词要换算（millones→million/billion）」。② 数字检查认识量级词（millones/millions/billion/milliard），换算后数值相同就不提示。③ 译文里出现源语言格式的数字（英语里的 1.400、西语里的 3.1）时，算作没通过检查：⏎ 改为复制，⌘⏎ 要确认「数字可能错了」。 | 21-pages-ai, 22-pages-ai-translation, 20-pages |
| E5-02 | P1 | 对照视图（AI 翻译） | 用 AI 翻译时，每段原文下面都显示**整篇译文**：2 段重复 2 遍，10 段重复 10 遍。原因：`PanelView.swift` 295–303 行，AI 翻译没有 `translatedParas`，就退回到 `Text(m.output)`。我用对照视图核对引语，这样完全没法用。 | AI 输出按 `\n` 分段，段数和原文相同就逐段配对；段数不同时不显示对照，只显示译文并说明「段落数对不上，只能看译文」。 | 21-pages-ai, 35-long-ai-done |
| E5-03 | P1 | 面板右上角的引擎切换 | 在面板里换一次 AI 翻译（`panel:aiTranslate`，相当于菜单「Translate with AI」）会写进 `gb_translate_ai`，设置里的开关也跟着打开。下一篇 852 词的稿子直接撞上 AI 的 3000 字符上限。没有任何提示说这个选择会被记住。 | 面板里的切换默认只对这一次有效（和 ⌘L 改目标语言一样），菜单里另给一项「以后都用 AI 翻译」；或者至少在切换时写一句「以后的翻译也会用 AI，可以在设置里改回」。 | 30-long-sys, 80-settings-lang |
| E5-04 | P1 | AI 超长界面（翻译时） | 852 词稿件：①「Process only the first **20** paragraph(s)」——实际只有 16 段，空行也被算成了段，处理后其实是 10 段；没有写「到哪一句为止」（§2.7）。② 说明写「Translation isn't limited this way」，但我**正在翻译**，界面上没有「改用系统翻译」按钮。 | 段数只数非空段，按钮写「只处理前 10 段（约 440 词，到『…』为止）」。翻译时把主按钮换成「用系统翻译整篇（最多 20000 字符）」，「只处理前 N 段」放第二位。 | 30-long-sys, 35-long-ai-done |
| E5-05 | P1 | 引导第 2、5 步 | 第 5 步说明写「This is plain text, so ⏎ replaces」，面板却说「Replacing here would lose formatting, so ⏎ copies」，⏎ 只是复制。第 2 步也说「Can't confirm this place is editable」，⌘⏎ 要确认「Formatting may be lost」。引导框是 App 自己的纯文本框。 | 引导里的文本框设成纯文本（`isRichText = false`），读取时标为 `.plain` + `.editable`，让 ⏎ 真的是替换；或者把说明改成和实际行为一致。第一次用就自相矛盾，很伤信任。 | 14-tryfix-1, 07-try-translate-1 |
| E5-06 | P1 | 系统翻译：对话破折号 | `—De la actualización … —respondió Benítez—. Está todo en el anexo tres.` → `"The updating …," Benítez replied. It's all in Annex Three.` 后半句引语变成了叙述。另一处对话同样如此。此外「la alcaldesa … aseguró」→「he assured」。 | 原文里有西语对话破折号（行首 `—` 加插入语 `—dijo X—`）时，在结果上方提示「原文有对话，系统翻译可能把引语和叙述混在一起，请核对」，并提供「用 AI 翻译这几段」。不改系统译文（§2.5），但要提醒。 | 32-long-sys-done |
| E5-07 | P1 | AI 翻译：目标语言标点 | 西→英时，AI 保留了 «» 和行首的对话破折号，逗号放在 » 里（`«We are not going to raise taxes,»`）。§2.5 要求译文用目标语言的标点习惯，设计稿也写了模型会把破折号原样带进英语。 | 译成英语时用规则清洗：«…» → "…"（或 “…”），行首 `—…—dijo X—.` 转成英语的引号句。像译成法语时的不换行空格一样，不依赖模型。 | 21-pages-ai, 35-long-ai-done |
| E5-08 | P2 | 数字提示文案 | 系统翻译正确的换算（1.400 millones → 1.4 billion，$2.5 billion → 2.500 millones）也显示「Numbers differ from the original」。 | 认识量级词后这类就不再提示；还要提示时写成「1.400 millones → 1.4 billion，请核对量级」，把两边都列出来，方便我一眼核对。 | 20-pages, 40-en-es-sys |
| E5-09 | P2 | 无障碍：需要下载语言包 | 进入 `needsDownload` 时没有播报（`PanelModel.swift` 341 行只设了 phase），`events.log` 里最后一句还是上一次的「Translate done…」。 | 进入这个状态时高优先级播报「法语 → 英语需要先下载一次语言包，按钮：下载、改用 AI 翻译」。 | 50-fr-sys |
| E5-10 | P2 | 长文面板大小 | 16 段对照还是 480 × 405，要滚很久。§2.7 说段落多时直接用 720 × 560。 | 按设计在段数多时放大面板，并记住大小。 | 32-long-sys-done |
| E5-11 | P2 | 改错：引语内的改动 | 「explicó」「dónde」在 «…» 里面被改，差异视图没有引号记号（`WordDiff.Flag.inQuote` 定义了但没显示）。记者改引语要格外小心。 | 按 §3 给引语内的改动加角标和「在引语内」朗读；可以考虑引语内的改动默认不采用。 | 60-es-fix |
| E5-12 | P2 | 引导第 1 步 / 测试接口 | `set:gb_languages=es,en` 存成了字符串，语言列表变空：界面仍显示 English / Chinese，Continue 变灰，没有任何说明。 | 测试接口的 `set:` 支持数组（例如 `es,en` 存成数组）。App 读到无效的语言列表时退回默认值，并刷新界面。 | 02-set-langs |
| E5-13 | P2 | 引导第 5 步示例语言 | 我的第 1 种语言是西语，改错示例却是英文，没让我看到它会不会改西语。 | 按第 1 种语言给示例（西语就用漏了 ¿ 和重音的句子）。 | 13-model-chosen |

## 测不了的部分会不会让我担心

- **写回 Pages**：这是我最担心的。我的稿子在 Pages 里，⏎ 是「插入到原文下方」，现在只记进了日志。我想知道插入后的样式会不会跟着标题走、«» 和长破折号会不会被 Pages 的智能引号再改一遍。M1 实测前，我会先只用 ⌘C。
- **macOS 15 的系统翻译**：我的 Mac 是 macOS 15，设计说那里要通过 SwiftUI 的 `.translationTask` 拿 session，这台 macOS 26 走的是另一条路。我最看重的长文系统翻译，恰恰是在我的系统上没有测过的那条路。如果在 macOS 15 上不能一次翻完 20000 字符，这个 App 对我的价值会少一大半。
- **语言包下载**：系统弹窗没测到。界面给了「改用 AI 翻译」的退路，我不太担心；但希望下载完会自动接着翻译（代码里 `downloadLanguages` 成功后会 `run()`，看起来是这样设计的）。
- **速度和内存**：16 GB 的 M2 跑 qwen3-14b，再开着 Pages 和 Safari，会很紧。AI 翻译 443 词这台机器就要 65 秒，在我的机器上可能要两分钟。对长稿我只会用系统翻译，AI 只用来改错和翻译短段落。
- **VoiceOver**：我不用，不担心。
