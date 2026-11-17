# 李娜（植物学博士生，Word + 修订，中译英）— 原型试用 Round 5

## 结论（评分 6.5/10；结构顺手了，但几个问题还在，现在还不会天天用）

改错本身让我很放心。我造的 5 段论文句子，里面有引用 [12,15]、[3–5]，大小写不同的基因名（FLC / flc-2 / fls2 / FLS2 / soc1-2），Col-0、Ler、35S::FLC-GFP，µmol m⁻² s⁻¹、± 这类记号，还有英式拼写（colour、analysed、summarised、vernalisation）。模型一处都没动这些，只改了主谓一致和 then/than，16 处改动全对，只漏了 1 处。Word 里 ⏎ 就是「写为修订」，写完能撤销，也能复制改动清单，正合导师的要求。

不打高分的原因：
- 引导第 4 步选了「用这台 Mac 上的模型」，再按蓝色的「继续」，模型**没有保存**，到第 5 步才说「还没有 AI」。像我这样不懂的人很容易在这一步卡住。
- 引导和测试窗口里明明写着「纯文本，⏎ 是替换」，实际 ⏎ 却是「复制」，还提示「可能丢格式」。第一次用就前后说法不一致，我会不信它。
- 我电脑上没有 LM Studio。这一步要我自己去 LM Studio 里打开「Developer → 本地服务」，对不会用终端、也没听说过 LM Studio 的人还是太难了。这台测试机已经装好，所以这一段我没能真的走一遍，下面根据界面和代码判断。
- 系统翻译译论文不行（把「长日照」译成 "long sunshine"），要换成 AI 翻译才像样，但没有人告诉我该换。

## 我的任务和过程

机器是 M5 Pro 24 GB。我的人物用 MacBook Air 16 GB，推荐的会是 Qwen3 8B，下面的速度都是这台机器上 Qwen3 14B 的结果，会比我的电脑快。

### 任务 1：第一次打开，走完引导、配好本机模型

1. `--launch --fresh` 后出现引导第 1 步（`01-start-0.png`）。默认「母语 = English，另一种 = 中文」，因为这台机器的系统语言是英文。我的母语是中文，应该反过来，但下拉框不能用测试接口点，就没改。两种语言互译，对我影响不大。下面写着「系统翻译的语言包已安装」，很安心。
2. 第 2 步「试一下翻译」：选中示例中文，按 ⌃⌘T，面板出来是「Chinese, Simplified → English」，译文 *Our experiments show that this method is better than the previous method in most cases.* 正确（`03-tr-1.png`）。底栏写「选中的文字不能编辑」，⏎ 是复制，说得清楚。
   - 测试接口的问题：我先用 `click:` 点了示例文字框，App 的事件循环就卡住了，只好 `pkill` 自己的实例再重开。不是产品问题，记在这里。
3. 第 3 步辅助功能权限，显示「Allowed」，有一段说明 Slack、Chrome 里会经过剪贴板，讲得很直白。
4. 第 4 步「选一个 AI」（`06-step4.png`）：两张卡片，代价一句话说清楚，我能看懂。点卡片的空白处没有反应，要点到标题文字附近才选中。选中后出现「LM Studio connected，Model: Qwen3 14B (loaded) (recommended)，Use this model」（`07-local.png`）。
5. **我直接按了右下角的「Continue」**，这是大多数人会按的。到第 5 步看到「No AI yet. Translation works now; turn on Fix any time in Settings → AI.」（`08-step5-noengine.png`）。我刚才明明选了，为什么没有？→ 问题 L5-01。
6. 退回第 4 步，点「Use this model」，它自动跳到第 5 步，这次有示例句子了（`10-step5.png`）。
7. 第 5 步「试一下改错」：选中 *Their are three reason why this approach work better then the previous one [12].*，按 ⌃⌘G。第一次面板显示「没有读到选中的文字」，因为关掉翻译面板后引导窗口不再是活动窗口了（见 L5-07）。重新激活窗口再按一次，大约几秒出结果，4 处改动全对，[12] 没动（`12-fix-1.png`）。
   - 可是引导上写「这里是纯文本，所以 ⏎ 是替换」，面板底栏却写「Replacing here would lose formatting, so ⏎ copies」，⏎ 是复制。→ 问题 L5-02。
   - 按 ⌘⏎，底栏变成「Formatting may be lost … Press ⌘⏎ again to confirm」（`13-cmdret1.png`），这句话把底栏的按钮挤出了面板。再按一次 ⌘⏎，示例文字真的被替换了，小条提示「Replaced. ⌘Z to undo」（`14-after-0.png`）。
8. 点「Done」。从打开到第一次改错成功：5 步，其中 1 步（Use this model）很容易漏掉。如果没装 LM Studio，还要再加上：下载 LM Studio、在它里面打开本地服务、在引导里下载模型（8B 约 4.6 GB）。

### 任务 2：测试窗口里改一句真的论文句子并替换

1. `open:test`，第一个框是 *Their are three reason why the flc-3 mutant flower earlier then Col-0 under long days (16 h light / 8 h dark), as previously reported [12, 15].*，正好是我会写的句子。
2. 全选后按 ⌃⌘G。和第 5 步一样，第一次读不到选区，激活窗口后再按就好了。结果 4 处：Their→There、reason→reasons、flower→flowers、then→than。flc-3 小写、Col-0、16 h、[12, 15] 都没动（`17-testfix-1.png`）。
3. 框上方标着「Plain text (⏎ should replace)」，⏎ 还是复制（同 L5-02）。
4. 用 ↓↓ 加空格撤回第 3 处（flowers），`finalText` 马上变回 flower，再按空格采用回来。逐处取舍用键盘就能做，很好。
5. ⌘⏎ 两次，替换成功（`19-replaced.png`）。

### 任务 3：Word 里改错，写成修订（`simulate:word`）

1. 原文 *Expression of FLC were reduced by 0.5× in Arabidopsis thaliana seedlings … which suggest that the vernalisation response is conserved.*
2. 约 3 秒出结果：were→was、suggest→suggests，vernalisation 保留英式拼写（`20-word.png`）。底栏 ⏎ 加粗写着「write as tracked changes」，正是我要的。**但底栏左右都被截掉了**，「2/2 accepted」只剩「cepted」，「Result」只剩「Res」→ L5-05。
3. 按 ⏎：面板留着，写「Wrote 2 tracked change(s) (QA simulation, Word not touched)」，有「Undo this change」和「Copy change list」（`21-word-written.png`）。说明文字的左边同样被截掉了。
4. 「Copy change list」复制出来是 `were → was / suggest → suggests`，可以直接贴进给导师的批注。「Undo this change」记成 `word.undo`。
5. 中文界面看了一遍（`32-zh-word.png`）：「改错 / 写为修订 / 复制 / 插到下方 / 差异 / 结果」，中文界面下底栏没有被截掉，用词自然。

### 任务 4：Word 里的中译英（`simulate:word-translate` 和我自己的段落）

1. 预设：*我们的结果表明，FLC 的表达在春化处理 30 天后下降了约一半 [12]。* 系统翻译：*Our results show that the expression of FLC decreased by about half after 30 days of vernalization treatment [12].* 正确（`23-word-tr.png`）。⏎ 是「insert below」，⌘⏎ 不可用，理由写得清楚。
2. 点 AI 翻译：*Our results show that FLC expression decreases by about half after 30 days of vernalization [12].* 更简洁，但 decreases 用了现在时，写结果应该用过去时。
3. 按 ⏎，小条「Inserted below the original. ⌘Z to undo」，面板关闭。
4. 我自己的段落 E，见下面「模型结果」。AI 翻译比系统翻译准得多（`30-trE.png` 和 `31-trE-sys.png`）。
5. 注意：在面板里点过一次「AI 翻译」以后，**以后所有翻译都默认用 AI 了**，面板上也没告诉我这是永久改了设置（L5-08）。

### 任务 5：自己造论文句子测改错（Word 场景）

见下面「模型结果」A–D，加上一次润色。测试接口的 `simulate:` 用 `;` 分命令，所以我句子里的分号都换成了逗号。真实使用不受影响，但「(n = 24; Figure 2B)」这类带分号的写法我没法测。

### 任务 6：出错时、中文界面、设置

- 我故意把模型设成一个没下载的名字（相当于「LM Studio 里没这个模型」），面板显示「⚠ Address or model not found (404)」和「Retry」（`35-err.png`）。我看不懂 404，也不知道该去哪里修，重试也不会好（L5-04）。`events.log` 里也没有这条错误的播报。
- 设置 → 写作（中文界面，`33-zh-writing.png`）：有「保护词表（区分大小写）」，但写着「系统翻译不读这个表」。设计稿里的「英语拼写变体」选项不在这里（L5-06）。输入框旁边还有一段带下划线的「duo j」，像是输入法没组完的字，我不确定是哪来的。
- 设置 → AI：有「这些 App 里只用本机的模型」，说明里提到「论文草稿」，正对我的需要。

## 模型结果

改错和润色用 LM Studio · qwen3-14b。思考时间 3–4 秒，一次改错实测约 3.3 秒。

| # | 原文 | 输出 | 对不对 | 敢不敢直接用 |
|---|---|---|---|---|
| 引导 | Their are three reason why this approach work better then the previous one [12]. | There are three reasons why this approach works better than the previous one [12]. | 全对，[12] 未动 | 敢 |
| 测试窗口 | Their are three reason why the flc-3 mutant flower earlier then Col-0 under long days (16 h light / 8 h dark), as previously reported [12, 15]. | There are three reasons why the flc-3 mutant flowers earlier than Col-0 … [12, 15]. | 全对，flc-3 / Col-0 / 引用 / 单位都没动 | 敢 |
| Word 预设 | Expression of FLC were reduced … which suggest that the vernalisation response … | … FLC was reduced … which suggests that the vernalisation response … | 对，英式拼写保留 | 敢（修订可以逐条拒绝） |
| A | The flc-2 and FLC alleles **was** compared in Col-0 and Ler backgrounds [12,15], and the FRI-Col allele **were** introgressed … (Michaels and Amasino, 1999). … 120 µmol m⁻² s⁻¹ light, and the colour of rosette leaves **were** recorded. | was→were、were→was、were→was | 3/3 对。flc-2 和 FLC 的大小写、Ler、[12,15]、µmol m⁻² s⁻¹、colour 都没动 | 敢 |
| B | We analysed the behaviour of 35S::FLC-GFP lines, which **flowers** later than wild type by 12.3 ± 1.4 d (n = 24, Figure 2B). These **datas** suggest that FLC protein **are** stable in the nucleus [3–5]. | datas→data、are→is | **漏改 1 处**：lines, which flowers → 应为 flower。其余对，analysed / behaviour / 35S::FLC-GFP / ± / [3–5] 都没动 | 敢写成修订，但要自己再读一遍 |
| C | In the fls2 mutant, FLS2 transcript **were** not detected, whereas the bak1-4 mutants **shows** a 2-fold increase in ROS (Fig. 3a) compared with Col-0 [7]. The SOC1 and soc1-2 results **is** summarised in Table S2. | were→was、shows→show、is→are | 3/3 对。fls2 和 FLS2、SOC1 和 soc1-2 没被统一大小写，summarised 保留 | 敢 |
| D | flc-3 plants **flowers** about 5 d earlier **then** Col-0, and FLC transcripts **was** barely detectable in the flc-3 background [12]. Leaf colour **were** scored at 21 DAG. | 4 处全改对 | 句首的 flc-3 **没有**被改成大写 Flc-3，这是我最怕的地方 | 敢 |
| A 润色 | 同 A | 和改错结果完全一样 | 润色很保守，什么都没重写。对论文来说这样安全，但「润色」名不副实 | 敢 |
| E 中译英（AI） | 以 Col-0 为对照，flc-3 突变体在长日照（16 h 光照/8 h 黑暗）条件下提前约 5 天开花（P < 0.01，n = 30），这与前人报道一致 [12, 15]。FLC 基因的表达量在 4 °C 处理 6 周后降至对照的 20%，而 flc-3 中几乎检测不到该转录本。 | Using Col-0 as the control, the flc-3 mutant flowers approximately 5 days earlier under long-day conditions (16 h light/8 h dark) (P < 0.01, n = 30), consistent with previous reports [12, 15]. The expression level of the FLC gene decreases to 20% of the control after a 6-week treatment at 4 °C, while the transcript is almost undetectable in flc-3. | 意思准确，记号、数字、引用都对，long-day 是正确术语。时态用了现在时（flowers / decreases），结果部分应该用过去时。拼写是美式 | 当草稿用，要改时态 |
| E 中译英（系统翻译） | 同上 | Taking Col-0 as **a contrast**, the flc-3 mutant **bloomed** about 5 days earlier under the condition of **long sunshine** (16 h light/8 h darkness) … the transcript was almost not detected in flc-3. | **术语错**：长日照不是 long sunshine，对照不是 contrast。bloomed 不够学术，almost not detected 不地道 | 不敢，论文里不能用 |
| Word 预设翻译（AI） | 我们的结果表明，FLC 的表达在春化处理 30 天后下降了约一半 [12]。 | Our results show that FLC expression decreases by about half after 30 days of vernalization [12]. | 意思对，时态应为 decreased | 改了时态再用 |

## 优点

1. **保护记号做得很好**：5 段句子里，大小写不同的基因名（FLC/flc-2、fls2/FLS2、SOC1/soc1-2）、句首的 flc-3、Col-0、Ler、35S::FLC-GFP、[12,15]、[3–5]、µmol m⁻² s⁻¹、±、P < 0.05 一个都没被动过；英式拼写（colour、analysed、behaviour、summarised、vernalisation）也全部保留。这正是我最担心的，这一项我放心了。
2. **Word 流程对路**：⏎ 默认就是「写为修订」，不会悄悄覆盖原文。写完面板留着，有「撤销本次修改」和「复制改动清单」（were → was 一行一条），我可以直接贴给导师。翻译在 Word 里只「插到下方」，不覆盖原文，理由写在底栏。
3. **差异视图和逐处取舍**清楚：删的字红色加删除线，加的字绿色加下划线；↓ 和空格就能撤回某一处，结果文字马上跟着变。
4. **面板总是写明文字去了哪里**：「This Mac · LM Studio · qwen3-14b」「System translation · on this Mac」。设置里还有「这些 App 里只用本机的模型」，说明里点名「论文草稿」。
5. **够快**：这台机器上改错约 3 秒，系统翻译 1 秒左右，不打断写作。
6. 中文界面翻得自然（「写为修订」「插到下方」「差异 / 结果」），没有机翻味。

## 问题清单

| ID | P0/P1/P2 | 位置 | 现象（复现步骤） | 建议 | 截图 |
|---|---|---|---|---|---|
| L5-01 | P1 | 引导第 4 步 | 选「Use a model on this Mac」，模型已经显示为 recommended，直接按右下角「Continue」。第 5 步显示「No AI yet」，模型没有保存。只有点卡片里那个灰色的「Use this model」才会保存。 | 选中本机模型的卡片后，「Continue」就等于「用这个模型」；或者没保存时不让继续，并说明还差哪一步 | `07-local.png` `08-step5-noengine.png` |
| L5-02 | P1 | 引导第 5 步、测试窗口的纯文本框 | 页面上写「This is plain text, so ⏎ replaces」/「Plain text (⏎ should replace)」，面板却说「Replacing here would lose formatting, so ⏎ copies」，⌘⏎ 还要确认「Formatting may be lost (can't tell…)」。第一次用就被告知两种相反的说法 | App 自己的文本框是知道是不是富文本的，应该判为纯文本，⏎ 是替换；看代码，经辅助功能接口读到时 `rich` 两个分支都是 `.unknown` | `10-step5.png` `12-fix-1.png` `17-testfix-1.png` |
| L5-03 | P1 | 中译英，系统翻译是默认 | 论文段落用系统翻译，长日照译成 "long sunshine"，对照译成 "contrast"，开花译成 "bloomed"。AI 翻译准得多，但默认是系统翻译，面板也没有提示「学术文字可以换 AI 翻译」 | 引导里问一句用途，或者在 Word、学术语气下默认 AI 翻译；至少在面板的译文下方给一个「用 AI 再译一次」的按钮 | `31-trE-sys.png` `30-trE.png` |
| L5-04 | P1 | 出错时的面板 | 模型在 LM Studio 里不存在时，只显示「Address or model not found (404)」和 Retry。不懂的人不知道 404 是什么，也不知道该去 LM Studio 下载模型还是去设置里换模型。`events.log` 里也没有这条错误的播报 | 写成「LM Studio 里找不到模型 qwen3-8b，去设置换一个，或者在这里下载」，加「去设置」按钮；出错时要播报 | `35-err.png` |
| L5-05 | P2 | 面板底栏（英文界面） | Word 改错结果的底栏左右被截掉：「2/2 accepted」只剩「cepted」，「Result」只剩「Res」。写完修订后「Wrote 2 tracked change(s)…」的左边也被截掉。⌘⏎ 的确认语占两行时，按钮被挤出面板（`13-cmdret1.png`） | 底栏内容放不下时换行或让面板变高；英文按钮文字可以缩短 | `20-word.png` `21-word-written.png` `13-cmdret1.png` |
| L5-06 | P2 | 设置 → 写作 | 没有设计稿里的「英语拼写变体」（英式 / 美式）。这次模型自己保留了英式拼写，但 AI 翻译输出的是美式 vernalization，和我论文正文不一致 | 加英式 / 美式选项，翻译和改错都按它来 | `33-zh-writing.png` |
| L5-07 | P2 | 引导 / 测试窗口，按快捷键 | 关掉一个面板后，引导窗口不再是活动窗口，紧接着选中文字再按 ⌃⌘G，面板说「没有读到选中的文字」。要先点一下窗口才行（我在测试接口里用 `focus` 模拟） | 关面板时把焦点还给引导或测试窗口，因为这里的「原 App」就是 GrammarBuddy 自己 | — |
| L5-08 | P2 | 面板，翻译引擎切换 | 在面板里点一次「AI 翻译」，之后所有翻译都默认用 AI（改的是全局设置 `translateWithAI`），面板没有说明 | 面板里的切换只对这一次生效，要不要「记住」由用户勾选（和 ⌘L 换语言一样） | — |
| L5-09 | P2 | 引导第 4 步的卡片 | 点卡片的空白处没有反应，要点到标题文字附近才选中（测试接口坐标点击，真实鼠标可能不一样） | 整张卡片都可以点 | `06-step4.png` |
| L5-10 | P2 | 润色 | 润色和改错的输出完全一样，没有任何改写。对论文来说这样安全，但我不知道润色到底做了什么 | 底栏一句话说明「润色只做了语法修正，没有需要改写的地方」 | — |
| L5-11 | P2 | 引导第 1 步 | 默认语言按系统语言，结果「母语 = English」。中文用户常常把系统语言设成英文 | 默认值也参考已启用的中文输入法（设计稿 §2.10 写了，这里好像没做到） | `01-start-0.png` |

## 测不了的部分会不会让我担心

- **Word 里真的写修订**：最担心。我的论文里引用是 EndNote 域，基因名是斜体，有上标单位（m⁻²），还有导师留下的未决修订和批注。设计稿说域里的改动会跳过，有未决修订时会提示，但这次全是模拟的，我没法知道真的写进去后格式和斜体会不会丢、EndNote 域会不会被弄坏。在亲眼看到它在我的真实文档里只留下干净的小修订之前，我只会先在一份副本上用。
- **没装 LM Studio 的安装路径**：这台机器已经装好并加载了模型，所以引导直接显示「已连上」。我的真实情况是要自己下载 LM Studio，再去它的「Developer → Status: Running」打开服务。这一步对我来说是最可能放弃的地方，我没能实际体验。另外 16 GB 内存的 MacBook Air 跑 8B 模型时，Word 和浏览器还开着，会不会卡，我也担心。
- **Word 的自动化授权弹窗**：第一次在 Word 里用会弹系统窗口，这次看不到。点错了「不允许」能不能找回来，我不知道。
- **语言包下载**：中英语言包已装好，没测到要下载的情况。对我影响不大。
