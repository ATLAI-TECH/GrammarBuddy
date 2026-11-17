# 标准测试文本

每次改完读写、面板或提示词，都用这一份文本在真实的 TextEdit 里走一遍。文本是 `GrammarBuddy-test.txt`，一段一行，共 6 段。

| 段 | 内容 | 操作 | 期望 |
|---|---|---|---|
| 1 | 学术英文，带 `flc-3`、`Col-0`、`16 h`、`[12, 15]` | 改错 → ⏎ | Their→There、reason→reasons、flower→flowers、then→than；记号、单位、引用一个都不能变；⏎ 是**替换**，TextEdit 里的文字真的变了 |
| 2 | 英文邮件 | 改错 → ⏎ | you're→your、attach→attached、their→there、problem→problems、friday→Friday |
| 3 | Slack 消息 | 改错 → ⏎ | has→have、tomorow→tomorrow、its→it's（开头的 hey 和 i 是聊天里的写法，改不改大写都算对） |
| 4 | 中文，带错别字 | 改错 → ⏎ | 这于→这与、一至→一致；`[12]` 不变；不能把「一至」整个删掉 |
| 5 | 西班牙语，带 `1.400 millones` | 翻译（手动测） | 英文里是 1.4 billion，不能是 1.400 million |
| 6 | 没有错的句子 | 改错 | 原样不动，面板写「模型没有找到要改的地方」 |

## 自动跑

```bash
qa/realtest.sh            # 用内置模型 Qwen3 4B；qa/realtest.sh mlx-community/Qwen3-14B-4bit 换 14B
```

脚本把文本复制到 `/tmp/gbtest/`，在 TextEdit 里打开副本，对第 1–4、6 段逐段：经辅助功能接口选中 → 改错 → 检查 ⏎ 是不是「替换」→ 按 ⏎ → 从 TextEdit 读回来比对。需要 GrammarBuddy 有辅助功能权限。
运行期间（约 1 分钟）请不要切换 App：脚本每一步都先确认最前面的是 TextEdit，不是就跳过那一步并记为失败，不会去动别的 App。

## 手动测

在 TextEdit 里打开 `GrammarBuddy-test.txt` 的副本，用鼠标选中一段，点旁边出现的「改错 | 翻译」按钮（或按 ⌃⌘G / ⌃⌘T），看结果，按 ⏎。⌘Z 应该能撤销。
把同样的文字贴进 TextEdit 的富文本文档、备忘录、Pages、Word、Chrome 里的输入框，再各试一遍。
