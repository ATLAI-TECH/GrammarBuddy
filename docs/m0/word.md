# M0：Word 验证（§5.5 的八个问题）

日期：2026-11-15。环境：Microsoft Word 16.114.4（macOS），从终端用 `osascript` 驱动，只用 Word 自己的 AppleScript 词典，没有用辅助功能。

脚本都在 `qa/m0/word/`：

| 文件 | 用途 |
|---|---|
| `read_selection.applescript` | 读选区：固定视图、读文字、记下域 / 未决修订 / 脚注 / 批注 / 表格的范围，最后恢复视图 |
| `write_edits.applescript` | 两遍写：第一遍只读比对（整段 + 每处两侧各一词），第二遍从后往前写成修订，返回每处生成的修订 |
| `reject_edits.applescript` | 「撤销本次修改」：在给定范围里逐条拒绝本次的修订 |
| `wordpos.py` | UTF-16 偏移 ↔ Word 位置的换算规则（问题 2） |
| `gbword.py` | 把上面三个脚本串起来的原型（WordReplacer 的参考实现） |
| `build_testdoc.py` | 在一个脚本新建的空文档里搭测试文档 |
| `wo.py` | 带超时的 osascript 封装 |
| `experiments/` | 每个问题的实验脚本（q1、q3、q4b、q4undo、q4bm、q7view、q8、charmap 等） |

## 结论一览

| # | 问题 | 结论 | 按 §5.5 决策表 / 对设计的影响 |
|---|---|---|---|
| 1 | 能不能按子范围写 | **通过** | 保留「写为修订」。只改中的那一小段；斜体、域、脚注、批注、上下标都在 |
| 2 | 位置怎么换算 | **通过**（有明确规则） | 读的时候必须同时记下域和「删除」修订的范围，按 `wordpos.py` 的规则换算。直接用 UTF-16 偏移当 Word 位置会写错地方（实测写错过） |
| 3 | 第一遍比对能否发现错位 | **通过**（两个条件） | 比较必须区分大小写（AppleScript 默认不区分）；整段比对要保留，只比两侧各一词在重复文字上会漏 |
| 4 | 能否拿回并逐条拒绝自己的修订 | **部分通过** | 提供「撤销本次修改」。条件：① 和未决修订**相邻**（不只是重叠）的改动也要跳过，否则 Word 把新旧修订并成一条；② 写后核对每处的修订都落在自己的范围里；③ 用隐藏书签记住范围，用户之后改了文档也能找到。`undo` 带次数可靠（开关修订不算一步），但只在写完立刻撤销时可靠，不建议用 |
| 5 | 选区里有未决修订时读到什么 | **通过**（要固定视图） | 固定成「最终状态 + 批注框显示修订」后，读到的是**接受后的样子**（不含被删的字）。§2.8「结果仅供参考、不提供写回」这条可以去掉，按「跳过重叠和相邻的改动」处理 |
| 6 | 能否取到域和未决修订的范围 | **通过**（有坑） | 能取到。但 `count of revisions of <范围>` 永远返回 0，要用 `revisions of <范围>` 的列表；批注要按「从选区起点到文末」去取再筛 |
| 7 | 读取方式、修订显示方式的影响 | **通过**（结论：固定视图） | `text retrieval mode` 在这个版本里读出来是 missing value，也设不了，不能用。读和写时都固定：`revisions view final`、`balloon revisions`、`show field codes false`、选区内每个域 `show codes false`，用完恢复 |
| 8 | 特殊字符读成什么；批注还在不在 | **部分通过** | 字符见下表，都能识别。批注：改批注范围**里面**的词，批注在；改批注范围的**最后一个词**或整段，用户接受修订时**批注会被一起删掉**。所以「触到批注范围边界的改动」要跳过（批注锚点在文字里没有字符，只能用读到的批注范围判断） |

耗时（osascript 冷启动约 100 ms 已含在内；App 内用 NSAppleScript 会少这部分）：

| 操作 | 中位数 |
|---|---|
| 只读选区文字（一条 `content of text object of selection`） | 108 ms（空调用 100 ms） |
| `read_selection`：固定视图 + 文字 + 全部元数据 + 恢复视图（3 个域、2 条修订） | 640 ms |
| 其中固定视图再恢复 | 约 100 ms |
| `write_edits`：5 处修订（整段比对 + 5 处比对 + 写 + 收集修订） | 980 ms |
| `reject_edits`：拒绝这 5 处生成的 10 条修订 | 770 ms |

## 建议改动设计的地方

1. **§5.5 读的第 3 步**：`text retrieval mode` 不可用（读是 missing value，设置报 -10006）。改成固定窗口视图的四项（见问题 7），读和写都要固定。
2. **§2.8 跳过规则**：「和已有的未决修订重叠」改成「重叠**或相邻**」。同一作者的相邻修订会被 Word 合并（实测：在别人的插入 "sleepy" 前面插入 "very "，变成一条 "very sleepy"），之后无法单独拒绝。GrammarBuddy 自己上一次的修订、用户自己开着修订打的字，作者都是用户本人，都会合并。
3. **§2.8 第 224 行**：有未决修订时能拿到「接受后的样子」，不用再拒绝写回。
4. **§2.8 跳过规则**：「批注的锚点」要具体成「改动的原文范围碰到批注范围的起点或终点」。改批注范围的最后一个词或整个范围，接受修订后批注被删；改第一个词，批注留下但新词落到批注范围外面。
5. **§5.5 写的第 5 步**：核对改成「每处生成的修订都在这一处的范围里，且类型是插入/删除」，不只是数条数。合并时修订会超出范围，这样能发现。
6. **§5.5 写的第 6 步**：「撤销本次修改」用隐藏书签（名字以 `_` 开头，如 `_GB_1`）记住每处的范围；书签会随用户后来的编辑移动。拒绝后删掉书签。面板关闭时也要删，否则会存进文件（无害，但多余）。
7. **新增跳过条件**：原文片段格式不统一（`italic of 范围` 等返回 missing value）。新写入的字沿用原范围第一个字的格式（实测：替换斜体词，新词是斜体；紧接斜体词后插入，新字也是斜体），片段内格式混杂时会丢格式。
8. **长度用 UTF-16 算**：AppleScript 的 `length` 把一个 emoji 算 1，Word 算 2。长度和位置都在 Swift 里按 UTF-16 算好再传给脚本。
9. **字符串比较**：AppleScript 的 `is` 默认不区分大小写（"PLANTS SUCH" 和 "Plants such" 判为相等）。比较必须写在 `tell application "Microsoft Word"` 外面的 handler 里并用 `considering case`，因为在 tell 块里 `case` 是 Word 的属性名，`considering case` 编译不过。

## 测试文档

`build_testdoc.py` 在脚本新建的空文档里搭出（Word 位置 0–434，读到的文字 315 个 UTF-16 单位）：

```
Plants such as Arabidopsis thaliana grow fast in the lab (Smith 2020) and H2O with x2 is used¹.
这是一段中文测试文字，用于检查位置换算。🌱 grows here.
See footnote 1 for details.
These are commented words here in the text.
The quick brown fox jumps over the sleepy dog.        ← lazy→sleepy 是写测试前做的未决修订
| A1 | B1 |
| A2 | B2 |
Final paragraph with date field: 2026-11-15.
```

| 元素 | 怎么做的 | 结果 |
|---|---|---|
| 斜体学名 | `set italic of (create range …) to true` | 成功 |
| 上下标 | `set subscript/superscript of font object of …` | 成功 |
| 引用域（代替 Zotero） | 先建 `QUOTE "(Smith 2020)"` 域，再把域代码改成 ` ADDIN ZOTERO_ITEM CSL_CITATION {…} ` | 成功：`field addin`，有结果 "(Smith 2020)"。直接 `create new field … field type field addin` 建出来的域**没有结果**、`show codes` 为 true，设置它的 `result range` 会把文字插到域后面 |
| 交叉引用 | `insert cross reference … reference type footnote … reference footnote number` | 成功（NOTEREF 域） |
| DATE 域 | `create new field … field type field date field text "\@ \"yyyy-MM-dd\""` | 成功。注意给了 field type 时 field text 不要再写 `DATE`，否则域代码变成 `DATE DATE …` |
| 脚注 | `make new footnote at <范围>` | 成功，但**它插在当前选区，不在给的范围**，要先 `select` 那个位置。返回的引用（`footnote 1 of text range id …`）取不到正文，要用 `footnote i of d` |
| 批注 | `make new Word comment at d with properties {comment text:…, scope:<范围>}` | 成功 |
| 表格 | `convert to table <范围> separator 1` | 成功。写 `separator separate by tabs` 报「不理解」（-1708），只能用整数 1 |
| 中文、emoji | 直接写在文字里 | 成功 |
| 「别人」的未决修订 | 开修订后替换 lazy → sleepy | **作者只能是用户本人**。换作者要改应用的 `user name`（全局偏好，不允许改）或者用 compare（要先存文件，见下面的「意外」），都没做。所以「不同作者的相邻修订会不会合并」没有验证 |

没能做的：嵌入对象（图片）、公式、尾注、文本框、真正的 EndNote 域。

**意外（重要）**：用脚本 `save as` 到 `/tmp/gb-word-m0/` 时，Word 弹出了对话框（沙盒外路径，推测是授权或另存为对话框），脚本卡住；之后 Word 里所有 `close` 都报「不理解」（-1708），读写照常。终端没有辅助功能权限，看不到也点不掉这个对话框。所以三个测试文档 Document6、Document7、Document8 还开着，**需要用户在 Word 里关掉那个对话框，再把这三个文档不保存关闭**。对 App 的意义：WordReplacer 不要让 Word 存文件。

## 问题 1：能不能按子范围写

做法：选中前 5 段，5 处改动（Plants→Plant、grow→grows（紧挨斜体学名）、fast→quickly、used→applied（紧挨脚注标记）、commented→annotated（批注范围的第一个词）），开修订，从后往前 `set content of (create range d start s end e) to new`（`experiments/q1.py`）。

```applescript
set track revisions of d to true
set r to create range d start 144 end 148   -- "used"
set content of r to "applied"
```

结果：

```
OK 5
EDIT 1 0 11    REV insert 0-5 / delete 5-11
EDIT 2 41 50   REV insert 41-46 / delete 46-50
EDIT 3 51 62   REV insert 51-58 / delete 58-62
EDIT 4 161 172 REV insert 161-168 / delete 168-172
EDIT 5 274 292 REV insert 274-283 / delete 283-292
文字：'Plant such as Arabidopsis thaliana grows quickly in the lab (Smith 2020) and H2O with x2 is applied\x02.\r…These are annotated words…'
italic(Arabidopsis thaliana) = true；italic("grows") = false
3 个域的代码和结果不变；脚注在、正文不变；下标 2、上标 2 还在
```

- 每处一条插入 + 一条删除。插入在前，删除紧跟在后。
- 改动写在域、脚注的旁边，域和脚注都不受影响。
- 范围跨过单元格结束符时，`set content` 直接报错 -10006，不会写坏表格。
- 对照：如果改动的原文片段跨过脚注标记或整个域，Word 会把它们作为删除修订；用户接受后脚注和域都没了（实测脚注 1→0，域 3→2）。所以 §2.8 的跳过规则是必要的。
- 改 DATE 域的结果（2026→2027）也能写成修订，但域一更新就没了，保持「落在域内部的改动跳过」。

## 问题 2：Word 位置和 UTF-16 偏移

逐个位置读 `content of (create range d start p end p+1)`（`experiments/charmap.applescript`，434 次调用 7.4 s）：

```
57  <missing value>   域开始符
58…109 ' ADDIN ZOTERO…'  域代码（单个位置读得到代码字符）
110 <missing value>   域分隔符
111…122 '(Smith 2020)'  域结果
123 <missing value>   域结束符
148 '\x02'            脚注标记
150 '\r'              段落标记
171 '' 172 ''         🌱 的两半（每半各占 1 个位置，单独读是空串）
325…328 <missing value>  被删除的 "lazy"
337 '\r\x07'          单元格结束符：1 个位置，读出 2 个字符
341 '\r\x07'          行结束符：同上
```

整篇：`end of content` = 434，读到的文字 315 个 UTF-16 单位。434 − 125（隐藏位置）+ 6（6 个单元格/行结束符各多 1）= 315。

**换算规则**（视图固定后，见问题 7）：

1. 读到的每个 UTF-16 单位对应 1 个 Word 位置：普通字母、中文、`\r`、`\t`、`\x0b`（换行符）、脚注标记 `\x02`、emoji 的两个代理项各 1。
2. 例外：`\r\x07`（单元格或行结束）是 2 个单位，对应 1 个位置。
3. 另外有不出现在文字里、但占位置的部分，要跳过：
   - 每个域：`[域代码起点 − 1, 结果起点)`（开始符 + 代码 + 分隔符），以及 `[结果终点, 结果终点 + 1)`（结束符）。
   - 每条「删除」修订的文字 `[起点, 终点)`。
4. 批注不占位置，也没有字符。

`wordpos.py` 实现了这条规则。拿 charmap 逐个对照：315 个单位，**0 处不符**。后续中文（测试→检测）、emoji（🌱→🌿）、emoji 后面的词（grows→grew）、表格单元格（A2→Z2）的写入都落在正确位置。

反例（真实踩到）：搭测试文档时直接把 "lazy" 在文字里的偏移当成 Word 位置，结果替换掉的是 `.\rTh`（差了 3 个域的隐藏长度）。

另外：选区的起点或终点落在域里面时，Word 会把选区扩大到包住整个域（选 115–140 → 实际 57–140；选 140–200 → 140–226）。

## 问题 3：第一遍比对能不能发现错位

做法（`experiments/q3.py`）：读完前 5 段，模拟用户在读和写之间改文档，然后只跑第一遍（`check` 模式）。三处改动 grow / commented / fox。

| 读后用户做了什么 | 整段 + 子范围 | 只比子范围 |
|---|---|---|
| 不改 | 通过 | 通过 |
| (a) 在开头插入 "Hello " | MISMATCH 0 | MISMATCH 1 |
| (b) 改选区后面的表格 | 通过（正确：位置没变） | 通过 |
| (c) 删掉选区里的 " fast" | MISMATCH 0 | MISMATCH 1 |
| (d) 重复文字 "na na na…" 前面插入 "na " | MISMATCH 0 | **通过（漏判，会改错一个 na）** |
| (e) 开着修订删掉开头的 "Plants " | MISMATCH 0 | 通过（位置其实没变，写也是对的） |

- (e) 说明：开着修订删字不移动后面的位置（删掉的字还占着位置）。
- (d) 说明：只比两侧各一词，在重复文字上会漏；整段比对必须保留。
- 大小写陷阱：

```
osascript write_edits.applescript Document7 "" check 0 0 "" 0 6 Plant 5 0 11 "PLANTS SUCH"
未加 considering case 时：CHECKED 1（错误地通过）
加上之后：            MISMATCH 1 Plants such
```

`write_edits.applescript` 的比较放在 tell 块外面的 `sameText` handler 里，用 `considering case, diacriticals, hyphens, punctuation and white space`。

## 问题 4：拿回自己的修订并逐条拒绝

**直接拒绝**：用写后报告的每处范围取 `revisions of (create range …)`，从后往前 `reject`（`reject_edits.applescript`）：

```
REJ 5 revision delete 283 292
REJ 5 revision insert 274 283
…
REJ 1 revision insert 0 5
→ 文字和写之前完全相同；别人那条 sleepy/lazy 还在；批注范围回到 "commented words"
```

**作者和时间不能用来区分**：作者是 Word 的用户名（就是用户本人，和他手改的一样），时间只到分钟（`07:12:00`）。只能靠范围。

**用户之后又改了文档**（`experiments/q4bm.py`）：写完给每处加隐藏书签，再在文首插入 "Hello. "：

```applescript
make new bookmark at d with properties {name:"_GB_1", text object:(create range d start 41 end 52)}
```

```
书签 _GB_1 41-52 → 插入后 48-59；_GB_2 257-275 → 264-282
按书签范围拒绝：REJ 2 delete 273-282 / insert 264-273 / REJ 1 delete 55-59 / insert 48-55，结果正确
```

**相邻会合并**（`experiments/q4b.py`）：在已有插入 "sleepy" 前插入 "very "：

```
EDIT 1 319 324
REV 1 revision insert 319 330   ← 超出了本处范围
修订列表：insert "very sleepy" 319-330 / delete "lazy" 330-334
```

拒绝这一条会把原来的 "sleepy" 一起拒绝。`reject_edits` 只拒绝完全落在范围里的修订，这一条会报 SKIP。所以要在写之前跳过相邻的改动，写后也要核对。

**undo**（`experiments/q4undo.py`）：

```
A：不开修订改一个词，再开、关一次修订，undo 1 → 改的词被撤销，文字恢复。开关修订不算一步。
B：write_edits 写 3 处（中间开关修订、改视图），undo 3 → 完全恢复，别人的修订还在。redo 1 / undo 1 也正常。
```

结论：一处改动 = 一步 undo，开关修订、改视图都不算。但 undo 撤的是 Word 撤销栈最上面的东西，用户在中间做过任何事就会撤错（测试里多撤一步就把更早的一次插入撤掉了）。按设计用「逐条拒绝」，不用 undo。

## 问题 5：选区里有未决修订时读到什么

视图不同，读到的不一样（`experiments/q7view.py`，选区 = 第 5 段，里面有 lazy→sleepy）：

| 视图 | `content of text object of selection` |
|---|---|
| 最终状态 + 批注框（Word 默认） | `The quick brown fox jumps over the sleepy dog.` |
| 最终状态 + 嵌入显示（in line） | `…over the sleepylazy dog.` |
| 最终状态 + mixed | `…over the sleepylazy dog.` |
| 草稿视图 | `…over the sleepylazy dog.` |
| 原始状态 | `…over the lazy dog.` |
| 不显示修订和批注 | 同默认 |

`read_selection` 固定成「最终状态 + 批注框」再读：用户视图是 in line 时，脚本读到 `…the sleepy dog.`，读完视图恢复成 in line。

子范围怎么对应：被删的字仍占 Word 位置（"lazy" 占 325–329），按问题 2 的规则跳过。实测在用户 in line 视图下改 "dog"→"cat"（紧跟在被删的 "lazy" 后面）和 "quick"→"fast"，位置都对，拒绝后完全恢复。

修订部分落在选区里时，`revisions of 选区` 给出整条修订的范围（选 322–334，得到 insert 319–325、delete 325–329），换算时照样能用。

## 问题 6：域和未决修订的范围

能取到，`read_selection` 的输出（整篇选中）：

```
FIELD field addin 58 110 111 123 false     （类型、代码起止、结果起止、原来的 show codes）
FIELD field note ref 200 223 224 225 false
FIELD field date 383 420 421 431 false
REV revision insert 319 325 <作者> Sunday, 15 November 2026 at 07:12:00
REV revision delete 325 329 <作者> …
FN 148
CM 250 265
TBL 335 349
```

坑：

- `count of revisions of <范围>` 永远是 0（整篇 0–434 也是 0），但 `revisions of <范围>` 列表正确，`revision i of <范围>` 也能用。文档级的 `count of revisions of d` 正常。
- `Word comments of <范围>` 只列出「批注范围的**终点**在这个范围里」的批注：选 240–260 时拿不到批注 250–265。脚本改成取「选区起点到文末」的批注，再留下起点 ≤ 选区终点的。
- `repeat with f in footnotes of d` 报 -1708；要用 `repeat with i from 1 to count …` 加下标。
- `fields of 选区` 正常。选区总会包住整个域（见问题 2）。
- 一次读取 3 个域、2 条修订、1 个批注，约 640 ms。

## 问题 7：读取方式和修订显示方式

```
set include field codes of text retrieval mode of r to true
→ Can't set include field codes of text retrieval mode of … to true. (-10006)
get {include field codes, include hidden text, view type} of text retrieval mode of r
→ missing value, missing value, missing value
```

对 `text object of d`、`create range` 的范围、`text object of selection` 都一样，`include hidden text`、`view type` 也一样。这个版本里 `text retrieval mode` 不可用。

视图对整篇文字的影响（默认 315 个单位）：

| 设置 | 长度 | 变化 |
|---|---|---|
| `revisions view original` | 313 | 显示 lazy，不显示 sleepy |
| `revisions mode in line revisions` | 319 | sleepy 和 lazy 都在 |
| `view type draft view` | 319 | 同上 |
| `show field codes true` | 410 | 三个域都变成 `\x13 代码 \x15`，结果不见了 |
| 单个域 `show codes true` | 357 | 只有这个域变成代码 |
| `show revisions and comments false`、`show insertions and deletions false`、`show all true`、`show hidden text true` | 315 | 不变 |

Word 位置（`end of content` = 434）在所有视图下都不变，变的只是读出来的文字。

读和写时固定：`revisions view final`、`revisions mode balloon revisions`、`show field codes false`、选区内 `show codes` 为 true 的域临时设成 false。四项都在 cleanup 里恢复（脚本里放在 try 之后无条件执行）。固定再恢复约 100 ms。

## 问题 8：特殊字符；批注还在不在

| 东西 | 读出来 | Word 位置 |
|---|---|---|
| 段落标记 | `\r` | 1 |
| 手动换行 | `\x0b` | 1 |
| 制表符 | `\t` | 1 |
| 脚注 / 尾注标记 | `\x02` | 1 |
| 单元格结束、行结束 | `\r\x07` | 1 |
| 域（正常显示） | 只有结果文字 | 开始符 + 代码 + 分隔符 + 结果 + 结束符 |
| 域（显示代码） | `\x13 代码 \x15` | 同上 |
| 批注锚点 | 什么都没有 | 0 |
| emoji（非 BMP） | 2 个代理项 | 2 |
| 嵌入对象、公式 | 没测 | — |

批注（`experiments/q8.py`，批注范围是 "commented words"，内容 "Check this phrase."）：

| 改的是 | 写后批注范围 | 用户接受修订后 |
|---|---|---|
| 第一个词 commented→annotated | `" words"`（新词在批注范围外） | 批注在，范围只剩 " words" |
| 最后一个词 words→terms | `"commented terms"` | **批注被删除** |
| 整个范围 → "flagged terms" | 只含被删的旧字 | **批注被删除** |
| 范围里面的词（另一条批注 "See footnote 1 for details" 里 for→with） | `"See footnote 1 with details"` | 批注在 |

拒绝修订时三种情况都能恢复原样。所以只要改动碰到批注范围的起点或终点就跳过；完全在批注范围里面的改动可以写。

## 附：Word 词典的其它坑（给 WordReplacer）

- 在 `tell application "Microsoft Word"` 里，变量名 `US` 会被当成 Word 的常量（输出成 "us"），`case` 是属性名。分隔符变量改名为 `kFS`、`kRS`。
- `insert " " at r` 报错，要写 `insert text " " at r`。
- `make new footnote` 返回的引用、`fields of r` 等返回的 `… of text range id «data …»` 引用，有的能用（revision、field），有的不能（footnote 的 text object），用之前先测。
- 脚本改单元格时，`paragraph 8` 可能是单元格里的段落，不要按段落号猜位置。
- 不要让 Word 用脚本保存到沙盒外路径（会卡在对话框上，之后 `close` 全部失效）。
