// Recommend.swift
// Design §2.4: what ⏎ does, and whether ⌘⏎ (put back) is available and what it must confirm.
// Pure function, unit-tested. Principle: when in doubt, copy.

import Foundation

public enum PanelAction: String, Sendable { case replace, trackedChange, insertBelow, copy }

public enum FinishReason: String, Sendable { case complete, truncated, cancelled }

public enum Confirmation: Equatable, Sendable {
    case failedChecks(String), losesFormatting(Int?), multilinePaste, maybeLosesFormatting

    public var text: String {
        switch self {
        case .failedChecks(let s): return L.t("检查没通过：", "Checks failed: ") + s
        case .losesFormatting(let n?): return L.t("选区里的 \(n) 处格式（链接、加粗等）会丢", "\(n) formatted item(s) in the selection (links, bold…) will be lost")
        case .losesFormatting(nil): return L.t("选区里的格式会丢", "Formatting in the selection will be lost")
        case .maybeLosesFormatting: return L.t("可能会丢格式（无法确认这段文字有没有格式）", "Formatting may be lost (can't tell whether this text has any)")
        case .multilinePaste: return L.t("要粘贴多行", "This pastes several lines")
        }
    }
}

public enum PutBack: Equatable, Sendable {
    case unavailable(String)
    case available([Confirmation])
}

public struct Recommendation: Equatable, Sendable {
    public var enter: PanelAction
    public var putBack: PutBack
    public var insertBelow: Bool
    public var enterReason: String?

    /// One merged sentence for the first ⌘⏎ press (§2.3).
    public var confirmText: String? {
        guard case .available(let cs) = putBack, !cs.isEmpty else { return nil }
        return cs.map(\.text).joined(separator: L.t("；", "; "))
    }
}

public struct RecommendInput: Sendable {
    public var capture: Capture
    public var profile: AppProfile
    public var operation: TextOperation
    public var checks: CheckResult
    public var finish: FinishReason
    public var leftPanel: Bool
    public var resultIsMultiline: Bool
    public var canInsertBelow: Bool

    public init(capture: Capture, profile: AppProfile, operation: TextOperation, checks: CheckResult, finish: FinishReason,
                leftPanel: Bool, resultIsMultiline: Bool, canInsertBelow: Bool) {
        self.capture = capture; self.profile = profile; self.operation = operation; self.checks = checks
        self.finish = finish; self.leftPanel = leftPanel; self.resultIsMultiline = resultIsMultiline; self.canInsertBelow = canInsertBelow
    }
}

public func recommend(_ i: RecommendInput) -> Recommendation {
    let c = i.capture
    let isWord = c.via == .word
    let insertBelow = i.canInsertBelow && i.finish == .complete
    let copyOrInsert: PanelAction = insertBelow ? .insertBelow : .copy

    // Rule 1: cannot write back at all
    var noWrite: String?
    if c.via == .manual || c.via == .service { noWrite = L.t("这段文字不是从 App 里读到的，只能复制", "This text wasn't read from an app, so it can only be copied") }
    else if i.profile.readOnly { noWrite = L.t("这个 App 是只读的（终端类），只能复制", "This app is read-only (a terminal), so results are copied") }
    else if c.editability == .readOnly { noWrite = L.t("选中的文字不能编辑", "The selected text isn't editable") }
    else if let l = i.checks.languageChanged, i.operation != .translate {
        noWrite = L.t("结果换成了另一种语言（\(l)），不能放回原处", "The result came back in another language (\(l)), so it can't be put back")
    }
    else if i.finish != .complete { noWrite = L.t("输出不完整", "The output is incomplete") }
    else if let w = c.wordCannotWrite { noWrite = w }
    else if c.via == .clipboard && i.leftPanel { noWrite = L.t("处理期间离开过面板，没法确认选区还在", "You left the panel while it was working, so the selection can't be confirmed") }
    else if isWord && i.operation == .translate { noWrite = L.t("Word 里的译文没有小片段可写，只能插入到原文下方", "In Word a translation can only be inserted below the original") }
    if let r = noWrite {
        let enter: PanelAction = (isWord && i.operation == .translate && insertBelow) ? .insertBelow : .copy
        return Recommendation(enter: enter, putBack: .unavailable(r), insertBelow: insertBelow && c.editability != .readOnly && !i.profile.readOnly,
                              enterReason: r)
    }

    var confirms: [Confirmation] = []
    var enter: PanelAction?
    var reason: String?

    // Rule 2: failed checks; for a translation, numbers that don't match (round 5 E5-01: 1.400 millones → "1.400 million")
    if i.operation == .translate && !i.checks.numberMismatch.isEmpty && !i.checks.failed {
        confirms.append(.failedChecks(L.t("译文里的数字和原文对不上：", "numbers differ from the original: ") + i.checks.numberMismatch.joined(separator: ", ")))
        enter = .copy
        reason = L.t("译文里的数字和原文对不上，请核对后再放回", "Numbers in the translation don't match the original; check before putting it back")
    }
    if i.checks.failed {
        confirms.append(.failedChecks(i.checks.summary))
        enter = .copy
        reason = L.t("检查没通过，所以默认是复制", "Checks failed, so ⏎ copies")
    }
    // Rule 3: Word, fix-type operations → tracked change
    if isWord {
        return Recommendation(enter: enter ?? .trackedChange, putBack: .available(confirms), insertBelow: insertBelow, enterReason: reason)
    }
    // Rule 4: editability unknown
    if c.editability == .unknown {
        if i.resultIsMultiline { confirms.append(.multilinePaste) }
        if enter == nil && !i.profile.assumeEditable {
            enter = .copy
            reason = L.t("不能确认这里可以编辑，所以默认是复制", "Can't confirm this place is editable, so ⏎ copies")
        }
    }
    // Rule 5: rich text or unknown
    let rich = i.profile.richText ?? c.richText
    if rich != .plain {
        confirms.append(rich == .rich ? .losesFormatting(c.formattingCount) : .maybeLosesFormatting)
        if enter == nil {
            if i.operation == .translate {
                enter = copyOrInsert
                reason = insertBelow ? L.t("译文插到原文下方，原文和格式不动", "The translation goes below the original, so its formatting stays")
                                     : L.t("这个 App 里替换会丢格式，所以默认是复制", "Replacing here would lose formatting, so ⏎ copies")
            } else {
                enter = .copy
                reason = L.t("这个 App 里替换会丢格式，所以默认是复制", "Replacing here would lose formatting, so ⏎ copies")
            }
        }
    }
    // Rule 6: editable plain text
    return Recommendation(enter: enter ?? .replace, putBack: .available(confirms), insertBelow: insertBelow, enterReason: reason)
}
