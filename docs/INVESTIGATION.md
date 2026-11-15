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
