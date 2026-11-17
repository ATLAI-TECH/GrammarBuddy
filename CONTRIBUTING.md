# Contributing to GrammarBuddy

**English** · [中文](#中文)

## Set up

1. macOS 15 or later, Xcode 16 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig`. Members of the ATLAI team keep `DEVELOPMENT_TEAM = 9A6Q68R555`. Everyone else empties it and builds with `scripts/dev-cert.sh` (a stable self-signed identity, so the Accessibility permission survives rebuilds).
3. `xcodegen generate`, then open `GrammarBuddy.xcodeproj`, or build from the command line:
   `xcodebuild -project GrammarBuddy.xcodeproj -scheme GrammarBuddy -configuration Debug -derivedDataPath build/dd build`
4. Run the core tests (no permissions needed): `cd GrammarBuddyKit && swift test`.

## Where things are

| Path | What |
|---|---|
| `GrammarBuddyKit/` | Everything without UI: diff, cleaning, checks, the ⏎ recommendation (`recommend`), language direction, AI backends. Unit-tested. |
| `GrammarBuddy/Panel/` | The floating panel, keyboard model, system translation. |
| `GrammarBuddy/Capture/` | Reading and writing the selection: accessibility, clipboard, Word (AppleScript). |
| `GrammarBuddy/App/` | Menu bar, onboarding, settings. |
| `GrammarBuddy/QA/` | DEBUG-only harness that lets scripts drive the app (`qa/gbqa.sh`) and the M0 probe. |
| `qa/model-eval/` | Corpus, prompts and the script that tests models (`run.py`). |
| `docs/` | Design, investigation, model results, review rounds. |

## Common changes

- **Add an AI engine**: implement `Backend` (`GrammarBuddyKit/Sources/GrammarBuddyKit/Backends/Backend.swift`) and add a case to `BackendFactory`. OpenAI-compatible services only need an entry in `APIService.all`.
- **Adapt an app**: add a line to `AppProfiles.swift` (reader, writer, read-only, rich text). Record what you tested in `docs/COMPATIBILITY.md`.
- **Change a prompt**: edit `GrammarBuddyKit/Sources/GrammarBuddyKit/Engine/Prompts/*.txt` and the copy in `qa/model-eval/prompts/`, run `python3 qa/model-eval/run.py --repeats 3 <model>` and put the before/after in the PR.
- **Drive the app from a script** (UI tests, screenshots): see the header of `GrammarBuddy/QA/QAHarness.swift`.

Pull requests: one topic each, tests passing, screenshots for UI changes. The licence is MIT.

---

## 中文

### 搭环境

1. macOS 15 以上，Xcode 16 以上，[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。
2. `cp Config/Local.xcconfig.example Config/Local.xcconfig`。ATLAI 团队成员保留 `DEVELOPMENT_TEAM = 9A6Q68R555`；其他人把它清空，用 `scripts/dev-cert.sh` 构建（固定的自签名证书，重编后辅助功能授权不会丢）。
3. `xcodegen generate`，然后打开 `GrammarBuddy.xcodeproj`，或用上面的命令行构建。
4. 核心测试不需要任何权限：`cd GrammarBuddyKit && swift test`。

### 常见改动

- **加一个 AI 引擎**：实现 `Backend`，在 `BackendFactory` 里加一行。OpenAI 兼容的服务只需要在 `APIService.all` 里加一项。
- **适配一个 App**：在 `AppProfiles.swift` 里加一行，并把实测结果写进 `docs/COMPATIBILITY.md`。
- **改提示词**：改 `Engine/Prompts/*.txt` 和 `qa/model-eval/prompts/` 里的同名文件，跑 `run.py --repeats 3`，把改前改后的结果放进 PR。
- **用脚本驱动 App**（界面测试、截图）：见 `GrammarBuddy/QA/QAHarness.swift` 文件头。
