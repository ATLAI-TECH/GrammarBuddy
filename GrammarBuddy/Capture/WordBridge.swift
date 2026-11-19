// WordBridge.swift
// Microsoft Word through its AppleScript dictionary (design §2.8, §5.5). Reads the selection,
// writes word-level edits as tracked changes, back to front, after a read-only verification pass.
// The scripts are the ones verified in M0 (qa/m0/word, docs/m0/word.md), bundled under Resources/Word;
// mapping and skip rules are in WordMap.swift. Word is never asked to save anything.

import AppKit
import Carbon
import GrammarBuddyKit

struct ScriptError: Error { var text: String; var number: Int = 0 }

@MainActor
enum WordBridge {
    static let bundleID = "com.microsoft.Word"

    /// Run AppleScript off the main thread; returns the result descriptor or an error string.
    static func run(_ source: String) async -> Result<NSAppleEventDescriptor, ScriptError> {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var err: NSDictionary?
                let script = NSAppleScript(source: source)
                let out = script?.executeAndReturnError(&err)
                if let out { cont.resume(returning: .success(out)) }
                else { cont.resume(returning: .failure(scriptError(err))) }
            }
        }
    }

    nonisolated static func scriptError(_ err: NSDictionary?) -> ScriptError {
        let n = err?[NSAppleScript.errorNumber] as? Int ?? 0
        return ScriptError(text: "\(n): " + ((err?[NSAppleScript.errorMessage] as? String) ?? "unknown"), number: n)
    }

    /// Run a bundled script's `on run argv` handler with `args` as argv, off the main thread.
    /// argv is delivered by sending the script an 'aevt'/'oapp' event whose direct parameter is a list of strings
    /// (what osascript does with its trailing arguments). Gives up after `timeout` seconds (Word blocked by a dialog).
    static func runScript(_ name: String, args: [String], timeout: TimeInterval = 30) async -> Result<String, ScriptError> {
        // shipped as source on purpose (project.yml): compiled at run time the scripts see Word's terminology
        guard let url = Bundle.main.url(forResource: name, withExtension: "applescript", subdirectory: "Word") else {
            return .failure(ScriptError(text: "missing script \(name)"))
        }
        return await withCheckedContinuation { cont in
            let once = Once()
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                if once.claim() { cont.resume(returning: .failure(ScriptError(text: "-1712: timed out", number: -1712))) }
            }
            DispatchQueue.global(qos: .userInitiated).async {
                var err: NSDictionary?
                guard let script = NSAppleScript(contentsOf: url, error: &err) else {
                    if once.claim() { cont.resume(returning: .failure(scriptError(err))) }
                    return
                }
                let argv = NSAppleEventDescriptor.list()
                for (i, a) in args.enumerated() { argv.insert(NSAppleEventDescriptor(string: a), at: i + 1) }
                let ev = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication),
                                                targetDescriptor: .currentProcess(), returnID: AEReturnID(kAutoGenerateReturnID),
                                                transactionID: AETransactionID(kAnyTransactionID))
                ev.setParam(argv, forKeyword: AEKeyword(keyDirectObject))
                let out = script.executeAppleEvent(ev, error: &err)
                guard once.claim() else { return }
                if err != nil { cont.resume(returning: .failure(scriptError(err))) }
                else { cont.resume(returning: .success(out.stringValue ?? "")) }
            }
        }
    }

    final class Once: @unchecked Sendable {
        private let lock = NSLock(); private var done = false
        func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func read(target: TargetApp) async -> Result<ReadOutcome, ReadFailure> {
        switch await runScript("read_selection", args: [], timeout: 20) {
        case .failure(let err):
            if err.number == -1743 || err.number == -10004 { return .failure(.automationDenied("Microsoft Word")) }
            return .failure(.noSelection)
        case .success(let out):
            let info = WordMap.parseRead(out)
            guard info.error == nil, info.end > info.start,
                  !info.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.noSelection) }
            // same UTF-16 length as the text read, so capture offsets map 1:1 (WordMap.display)
            var cap = Capture(raw: WordMap.display(info.text), via: .word, editability: info.readOnly ? .readOnly : .editable, richText: .rich, app: target)
            info.leading = (cap.leading as NSString).length
            // only the main story is written to (§2.8)
            if !info.storyType.contains("main text") {
                cap.wordCannotWrite = L.t("选区在脚注、批注、文本框或页眉页脚里，这里不写回", "The selection is in a footnote, comment, text box or header, so it isn't written back")
            }
            if info.readOnly { cap.wordCannotWrite = L.t("文档是只读的", "The document is read-only") }
            if !info.protection.isEmpty && !info.protection.contains("no document protection") {
                cap.wordCannotWrite = L.t("文档设了保护（限制编辑），不写回", "The document is protected (restricted editing), so it isn't written back")
            }
            // Pending revisions no longer block the write: with the view pinned the text read is the accepted
            // version, and changes touching a revision are skipped one by one (docs/m0/word.md, question 5).
            if !info.revisions.isEmpty { cap.notes.append(.wordHasPendingRevisions) }
            if !info.fields.isEmpty { cap.formattingCount = info.fields.count }
            var h = WriteHandle(pid: target.pid, wordStart: info.start, wordEnd: info.end)
            h.wordInfo = info
            return .success(ReadOutcome(capture: cap, handle: h, bounds: nil, windowFrame: nil))
        }
    }

    /// Change index → reason it is not written to Word (§2.8). See WordMap.skipped.
    static func skipped(_ changes: [Change], info: WordReadInfo, bySentence: Bool = false) -> [Int: String] {
        WordMap.skipped(changes, info: info, bySentence: bySentence)
    }

    struct WordWriteResult { var written: Int; var skipped: Int; var message: String; var ok: Bool }

    /// Write accepted changes straight into the document (user decision 2026-11-17: no tracked changes that then have
    /// to be accepted a second time in Word; they already chose in the panel). If the document itself has Track Changes
    /// on, Word records them, as the document's owner asked. `changes` ranges are UTF-16 offsets in `capture.text`.
    static func writeTracked(_ changes: [Change], capture: Capture, handle: WriteHandle) async -> WordWriteResult {
        guard let info = handle.wordInfo,
              WordMap.display(info.text) == capture.leading + capture.text + capture.trailing else {
            return WordWriteResult(written: 0, skipped: 0, message: L.t("这段文字和从 Word 读到的不一致，没有写入", "This text no longer matches what was read from Word; nothing was written"), ok: false)
        }
        let skip = skipped(changes, info: info)
        let picked = changes.enumerated().filter { $0.element.accepted && skip[$0.offset] == nil }.map(\.element)
        let (todo, dropped) = WordMap.coalesce(picked, info: info)
        let skippedCount = changes.filter(\.accepted).count - picked.count + dropped
        guard !todo.isEmpty else {
            return WordWriteResult(written: 0, skipped: skippedCount, message: L.t("没有可以写入的修改", "There is nothing that can be written"), ok: false)
        }
        let args = WordMap.writeArgs(todo, info: info)
        switch await runScript("write_edits", args: args, timeout: 60) {
        case .failure(let e):
            return WordWriteResult(written: 0, skipped: skippedCount, message: L.t("没能写入 Word：", "Couldn't write to Word: ") + e.text, ok: false)
        case .success(let out):
            let o = WordMap.parseWrite(out)
            if let m = o.mismatch {
                let why = m.index == 0 ? L.t("文档或选区在读取之后变了", "the document or selection changed after it was read")
                                       : L.t("第 \(m.index) 处的原文变了", "the text at change \(m.index) changed")
                return WordWriteResult(written: 0, skipped: skippedCount, message: L.t("Word 里的位置对不上（\(why)），没有修改", "The position in Word no longer matches (\(why)); nothing was changed"), ok: false)
            }
            if let e = o.error {
                info.writtenRanges = []
                return WordWriteResult(written: 0, skipped: skippedCount, message: L.t("写入时 Word 报错：", "Word reported an error while writing: ") + e, ok: false)
            }
            info.writtenRanges = o.tracked ? o.edits.map { ($0.start, $0.end) } : []
            info.writtenPlain = []
            if !o.tracked {
                // EDIT k is the k-th change in document order: keep what was there, to put it back on undo
                let ordered = todo.sorted { $0.range.location < $1.range.location }
                for e in o.edits where e.k >= 1 && e.k <= ordered.count {
                    let c = ordered[e.k - 1]
                    info.writtenPlain.append((e.start, c.inserted.replacingOccurrences(of: "\n", with: "\r"), c.removed.replacingOccurrences(of: "\n", with: "\r")))
                }
            }
            var msg = o.tracked ? L.t("已写入 \(o.edits.count) 处修订（这个文档开着修订）", "Wrote \(o.edits.count) tracked change(s) (Track Changes is on in this document)")
                                : L.t("已替换 \(o.edits.count) 处", "Replaced \(o.edits.count) place(s)")
            if skippedCount > 0 { msg += L.t("，\(skippedCount) 处没有写入", "; \(skippedCount) not written") }
            let stray = o.tracked ? o.strayEdits : []
            if !stray.isEmpty {
                msg += L.t("。第 \(stray.map(String.init).joined(separator: "、")) 处和旁边的修订合并了，撤销时可能要在 Word 里手动处理",
                           ". Change(s) \(stray.map(String.init).joined(separator: ", ")) merged with a neighbouring revision; undo may need Word's Revisions pane")
            }
            return WordWriteResult(written: o.edits.count, skipped: skippedCount, message: msg, ok: !o.edits.isEmpty)
        }
    }

    /// Undo this write by rejecting exactly the revisions it produced (§2.8 "撤销本次修改").
    /// Uses the EDIT ranges recorded by writeTracked; `newLength` is kept for the call site and unused.
    static func rejectRevisions(capture: Capture, handle: WriteHandle, newLength: Int) async -> Bool {
        guard let info = handle.wordInfo else { return false }
        if !info.writtenPlain.isEmpty {
            // direct replacements: put the old text back, last one first, each only if the new text is still there
            var lines = ""
            for e in info.writtenPlain.sorted(by: { $0.start > $1.start }) {
                let end = e.start + (e.new as NSString).length
                lines += """
                    set r to create range d start \(e.start) end \(end)
                    set c to content of r
                    if c is missing value then set c to ""
                    if my sameText(c, "\(escape(e.new))") then
                        set content of r to "\(escape(e.old))"
                    else
                        set bad to bad + 1
                    end if

                """
            }
            let src = """
            on sameText(a, b)
                considering case
                    return a is b
                end considering
            end sameText
            tell application "Microsoft Word"
                set d to document "\(escape(info.docName))"
                set bad to 0
            \(lines)
                return bad as text
            end tell
            """
            info.writtenPlain = []
            if case .success(let d) = await run(src) { return d.stringValue == "0" }
            return false
        }
        guard !info.writtenRanges.isEmpty else { return false }
        let args = [info.docName] + info.writtenRanges.flatMap { [String($0.0), String($0.1)] }
        guard case .success(let out) = await runScript("reject_edits", args: args, timeout: 60) else { return false }
        let recs = WordMap.records(out)
        info.writtenRanges = []
        return recs.contains { $0.first == "REJ" } && !recs.contains { $0.first == "SKIP" }
    }

    /// Live check: replace one piece in the active document's body.
    ///
    /// `start` is the UTF-16 offset in the page text as Accessibility reports it plus the page's offset. In plain text
    /// that is Word's character position, but NOT in a real document: Accessibility adds words Word doesn't have
    /// ("Field", "Table, 2 Rows, 2 Columns", footnote numbers) and leaves out what Word counts (field codes, deleted
    /// tracked text, cell marks). So the position is only a first guess:
    ///   1. the text there, together with the text just before and after it, must match exactly (case-sensitive);
    ///   2. if it doesn't, the same snippet is searched in the document; it must occur exactly once. Its Word position
    ///      is found by bisection (length of the text before a position) and then compared again before writing.
    /// If neither works nothing is changed. `write: false` only locates (used to drop marks that can't be applied).
    static func liveReplace(start: Int, removed: String, inserted: String, before: String = "", after: String = "",
                            write: Bool = true) async -> (ok: Bool, message: String) {
        let lb = (before as NSString).length, lr = (removed as NSString).length, la = (after as NSString).length
        let src = """
        on sameText(a, b)
            considering case
                return a is b
            end considering
        end sameText
        on findOnce(T, s)
            considering case
                set k to offset of s in T
                if k is 0 then return 0
                if k < (length of T) then
                    if (offset of s in (text (k + 1) thru -1 of T)) is not 0 then return -1
                end if
                return k
            end considering
        end findOnce
        tell application "Microsoft Word"
            set d to active document
            set snippet to "\(escape(before + removed + after))"
            set removedText to "\(escape(removed))"
            set p to \(start)
            set ok to false
            if p ≥ \(lb) then
                try
                    set c to content of (create range d start (p - \(lb)) end (p + \(lr + la)))
                    if c is not missing value then set ok to my sameText(c, snippet)
                end try
            end if
            if not ok then
                set T to content of text object of d
                set k to my findOnce(T, snippet)
                if k is 0 then return "notfound"
                if k is -1 then return "ambiguous"
                -- number of characters of the document text in front of the piece to change
                set want to (k - 1) + (length of "\(escape(before))")
                set docEnd to (end of content of text object of d)
                -- last position with exactly `want` characters in front of it: directly before the piece
                set lo to 0
                set hi to docEnd
                repeat while lo < hi
                    set mid to (lo + hi + 1) div 2
                    set c to content of (create range d start 0 end mid)
                    if c is missing value then set c to ""
                    if (length of c) ≤ want then
                        set lo to mid
                    else
                        set hi to mid - 1
                    end if
                end repeat
                set p to lo
                set c to content of (create range d start 0 end p)
                if c is missing value then set c to ""
                if (length of c) is not want then return "notfound"
                if \(lr) > 0 then
                    set c to content of (create range d start p end (p + \(lr)))
                    if c is missing value then return "notfound"
                    if not (my sameText(c, removedText)) then return "notfound"
                else
                    -- an insertion: if hidden material (a field code, deleted text) sits at this spot there are several
                    -- positions with the same text in front; don't guess which side of it is meant
                    if p > 0 then
                        set c to content of (create range d start 0 end (p - 1))
                        if c is missing value then set c to ""
                        if (length of c) is want then return "notfound"
                    end if
                end if
            end if
            if \(write ? "true" : "false") then
                set r to create range d start p end (p + \(lr))
                set content of r to "\(escape(inserted))"
            end if
            return "ok"
        end tell
        """
        switch await run(src) {
        case .failure(let e):
            if e.text.hasPrefix("-1743") { return (false, L.t("需要允许 GrammarBuddy 控制 Word（系统设置 → 隐私与安全性 → 自动化）", "Allow GrammarBuddy to control Word (System Settings → Privacy & Security → Automation)")) }
            return (false, L.t("Word 没有接受这次修改：", "Word didn't accept the change: ") + e.text)
        case .success(let d):
            switch d.stringValue {
            case "ok": return (true, "")
            case "ambiguous": return (false, "ambiguous")
            default: return (false, "notfound")
            }
        }
    }

    /// The body text of the active document as Word itself has it (paragraph marks as "\r"). Used to tell words that
    /// only Accessibility adds ("Field" before a Zotero citation) from words that are really in the document.
    static func documentText() async -> String? {
        let src = """
        tell application "Microsoft Word"
            set c to content of text object of active document
            if c is missing value then return ""
            return c
        end tell
        """
        if case .success(let d) = await run(src) { return d.stringValue }
        return nil
    }

    static let liveNotFound = L.t("在 Word 里找不到这处文字（它可能在域、脚注或表格里，或者刚被改过），没有修改",
                                  "Couldn't find this text in Word (it may be inside a field, footnote or table, or was just edited); nothing was changed")

    static func insertBelow(_ text: String, handle: WriteHandle) async -> Bool {
        guard let en = handle.wordEnd else { return false }
        let src = """
        tell application "Microsoft Word"
            set r to create range active document start \(en) end \(en)
            set p to end of text object of (paragraph 1 of r)
            set ip to create range active document start (p - 1) end (p - 1)
            insert text "\r\(escape(text.replacingOccurrences(of: "\n", with: "\r")))" at ip
            return "ok"
        end tell
        """
        if case .success = await run(src) { return true }
        return false
    }
}
