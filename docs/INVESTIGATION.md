# 可行性调查（2026-11-14）

设计之前在作者的 Mac 上做的实测（macOS 26.6.1，Xcode 27.1，Microsoft Word，LM Studio）。
`DESIGN.md` 里的每个技术决定都以这里为依据；没实测过的地方在这里和设计稿里都标了「未验证」。

## 结论

可行。四个部分里三个实测通过，只有「像 Grammarly 那样在任意 App 里实时画下划线」不建议做。

| 功能 | 结论 | 依据 |
|---|---|---|
| 系统翻译 + 快捷键翻译选中文本 | 可行，工作量最小 | CapyBuddy 的截图翻译已经在用系统翻译；全局快捷键也有现成实现 |
| 本地 AI 改错 / 改写 | 可行，但要自带模型 | 实测小模型改错约 1 秒，质量够用 |
| 在 Word 里直接改文本 | 可行 | 实测通过脚本接口替换选中文字成功，并且能走「修订」模式 |
| 任意 App 内实时下划线提示 | 不建议 | 需要逐个 App 适配文字坐标；Grammarly 自己在 Word 里也是用专门的 Office 插件做的 |

## 实测细节

- **Word**：新建一个临时文档，把选中的 "Their" 替换成 "There" 成功。开启修订后再替换，Word 记录了 2 条修订（删除 + 插入），所以 AI 的修改可以作为修订让用户逐条接受或拒绝。
- **本地模型**：用 LM Studio 里的 gemma-4-e4b（约 6 GB）测了一段带语法错误的学术英文：
  - 改错：0.8–1.5 秒，结果正确。
  - 改写和英译中：各约 5–6 秒，质量可用。大部分时间花在模型的「思考」输出上，关掉后应该明显更快，**未验证**。
- **Apple 自带模型**：这台机器返回「Apple Intelligence 未启用」，所以不能依赖它，只能作为「有就用」的可选后端。
- **系统翻译**：无界面直接调用要求语言包已安装；这台机器英→简中显示为「支持但未安装」，直接调用报错。需要沿用截图翻译现在的做法，首次使用时弹系统的下载语言包窗口。

## 限制

- 读取其他 App 的选中文本需要辅助功能权限。测试用的终端没有这个权限，所以 **Word 之外的通用读写没有实测**。稳妥的做法是先用辅助功能接口读，失败就退回模拟 ⌘C / ⌘V。
- 控制 Word 会弹一次「允许 GrammarBuddy 控制 Microsoft Word」的系统授权。
- 模型有几个 GB，不能打进安装包，需要首次使用时下载，并占用几个 GB 内存。把模型嵌进 App 的库（MLX Swift 或 llama.cpp）只查了资料，**没有实际集成验证**，各来源的版本信息不一致。

## SDK 核对（写设计稿时补查）

在本机 Xcode 27.1 的 macOS SDK 里核对过：

- `Translation.framework` 存在。`TranslationSession.init(installedSource:target:)` 标注 macOS 26.0+；更早的系统只能通过 SwiftUI 的 `.translationTask` 拿到 session。
- `FoundationModels.framework` 存在（Apple 自带模型的接口）。

## 资料来源

- [Grammarly 工程博客：Mac 版 Word 插件的实现](https://www.grammarly.com/blog/engineering/building-microsoft-word-add-in-mac/)
- [Grammarly 为何需要辅助功能权限](https://support.grammarly.com/hc/en-us/articles/360059770451-Why-does-Grammarly-need-access-to-accessibility-features)
- [Microsoft Q&A：AXUIElementSetAttribute 在 Word 上不生效](https://learn.microsoft.com/en-us/answers/questions/1324855/macos-axuielementsetattribute-not-working-on-word)
- [Swift.org：MLX Swift 介绍](https://swift.org/blog/mlx-swift/)
- [mlx-swift-lm 包](https://swiftpackageregistry.com/drewster99/mlx-swift-lm)

## 补充：多语言模型实测（2026-11-14 晚）

用六种语言的 41 条语料重测了本地模型，结果在 [`MODELS.md`](MODELS.md)。它修正了上面两处说法：

- 上面写「改错 0.8–1.5 秒」。那是短句配短提示词、模型没有思考时的速度。换成设计稿里的提示词和带引用、数字的句子后，同一个模型（gemma-4-e4b）41 条里有 37 条先思考，中位数 12.5 秒。
- 上面写「大部分时间花在模型的思考输出上，关掉后应该明显更快，未验证」。验证了：经 LM Studio 试过的参数都关不掉 gemma-4 的思考，其中两种还会让思考过程混进正文。

另外：17 GB 的 qwen 27B 在这台 24 GB 的机器上跑不动；测试中途本地服务被另一个进程停过一次，脚本现在会自动重启它。

## M0 地基验证（2026-11-15）

能在这台机器上自动做的部分都做了；要给 GrammarBuddy 授权（辅助功能、自动化）之后才能做的，列在最后。

### Word 的脚本接口：八个问题

详细记录在 [`m0/word.md`](m0/word.md)，脚本在 `qa/m0/word/`，App 里用的是同一套脚本（`GrammarBuddy/Resources/Word/`）。

| # | 问题 | 结论 |
|---|---|---|
| 1 | 能不能按子范围写 | 能。5 处修订紧挨着斜体学名、引用域、脚注标记、批注，格式和域都没动 |
| 2 | 字符位置和 UTF-16 怎么对应 | 每个 UTF-16 单位一个位置（emoji 两个）；单元格结束符读出来两个字符、占一个位置；域的开始符、域代码、分隔符、结束符和未决删除占位置但不在文字里。434 个位置逐一核对无误 |
| 3 | 写前比对能不能发现错位 | 能，但比较必须区分大小写（AppleScript 默认不区分），并且必须保留整段比对 |
| 4 | 能不能拿到并拒绝自己写的修订 | 部分。按范围拒绝可以精确恢复；但紧挨着已有修订、作者相同的新修订会被 Word 合并。`undo` 带次数在用户中途有操作时不可靠，不用 |
| 5 | 选区里有未决修订时读到什么 | 固定视图为「最终状态 + 批注框显示修订」时读到接受后的文字 |
| 6 | 能不能取到域和修订的范围 | 能。`count of revisions of <range>` 总是 0，要用列表 |
| 7 | 读取方式的影响 | `text retrieval mode` 读写都不可用；读到的文字由窗口视图决定，读写时固定四项视图设置，用完恢复 |
| 8 | 特殊字符 | 脚注标记 `\x02`、段落 `\r`、换行 `\x0b`、单元格 `\r\x07`；批注锚点不占字符。替换批注范围内的词批注还在，替换整个批注范围会在接受时删掉批注 |

用时：读选区（含所有范围）640 ms，写 5 处修订（两遍）980 ms，拒绝 10 条修订 770 ms。

App 里的 Word 写回已经按这些结论实现，并在终端里对真实 Word 跑通了读 → 写 → 拒绝的完整一轮（位置表和 Python 参考实现 316 项一致，拒绝后文字逐字恢复）。App 自己调用 Word 还没跑过，因为需要用户点一次「允许控制 Word」。

### 本机模型：思考关掉了

Qwen3 4B / 8B / 14B 经 LM Studio 自己的接口（`reasoning: "off"`），136 条语料每条 3 次，共 1224 次调用，没有一次思考、没有一次空输出，每条中位数 0.3 / 0.5 / 0.8 秒。质量见 [`MODELS.md`](MODELS.md)。

### 还要在真机上做的

这台机器上的测试进程没有辅助功能权限，测试版 App 也没有授权，所以下面这些没做：

- 面板的键盘模型在 10 个 App 里的表现（M0 清单「窗口和键盘」1–7 条）。App 自己的窗口里验证过：面板出现即拿到键盘、动作在松开按键时执行、⌘Q / ⌘W / ⌘H 只关面板、Esc 关闭。
- 读写探针：DEBUG 版菜单里有「M0 探针」，授权后切到要测的 App、选中文字、点菜单，结果追加到 `~/Library/Logs/GrammarBuddy/probe.jsonl`（只在 TextEdit 里试写入）。
- 快捷键冲突：Carbon 注册在这台机器上成功；在各 App 前台时是否被拦截要真机试。
- 中文、日文输入法下的回车。
