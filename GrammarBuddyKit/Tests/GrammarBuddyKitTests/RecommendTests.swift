import XCTest
@testable import GrammarBuddyKit

final class RecommendTests: XCTestCase {
    override func setUp() { UserDefaults.standard.set("en", forKey: L.key) }

    private func capture(_ via: CaptureSource, _ e: Editability, _ r: RichText, formatting: Int? = nil,
                         wordCannotWrite: String? = nil) -> Capture {
        var c = Capture(raw: "Their are many reasons.", via: via, editability: e, richText: r)
        c.formattingCount = formatting
        c.wordCannotWrite = wordCannotWrite
        return c
    }

    private func failedChecks() -> CheckResult {
        var c = CheckResult(); c.droppedWords = ["müssen"]; return c
    }

    private func rec(_ cap: Capture, profile: AppProfile = AppProfile(), op: TextOperation = .fix,
                     checks: CheckResult = CheckResult(), finish: FinishReason = .complete, leftPanel: Bool = false,
                     multiline: Bool = false, canInsertBelow: Bool = false) -> Recommendation {
        recommend(RecommendInput(capture: cap, profile: profile, operation: op, checks: checks, finish: finish,
                                 leftPanel: leftPanel, resultIsMultiline: multiline, canInsertBelow: canInsertBelow))
    }

    private func isUnavailable(_ p: PutBack) -> Bool { if case .unavailable = p { return true }; return false }
    private func confirms(_ p: PutBack) -> [Confirmation]? { if case .available(let cs) = p { return cs }; return nil }

    // MARK: rule 1 — cannot write back

    func testTerminalIsCopyOnly() {
        let r = rec(capture(.accessibility, .unknown, .plain), profile: AppProfiles.profile(for: "com.apple.Terminal"))
        XCTAssertEqual(r.enter, .copy)
        XCTAssertTrue(isUnavailable(r.putBack))
        XCTAssertNil(r.confirmText)
        XCTAssertFalse(r.insertBelow)
        let t = rec(capture(.accessibility, .unknown, .plain), profile: AppProfiles.profile(for: "com.googlecode.iterm2"), op: .translate)
        XCTAssertEqual(t.enter, .copy)
        XCTAssertTrue(isUnavailable(t.putBack))
    }

    func testReadOnlySelection() {
        let r = rec(capture(.accessibility, .readOnly, .rich), canInsertBelow: true)
        XCTAssertEqual(r.enter, .copy)
        XCTAssertTrue(isUnavailable(r.putBack))
        XCTAssertFalse(r.insertBelow)
    }

    func testTruncatedAndCancelled() {
        for f in [FinishReason.truncated, .cancelled] {
            let r = rec(capture(.accessibility, .editable, .plain), finish: f, canInsertBelow: true)
            XCTAssertEqual(r.enter, .copy)
            XCTAssertTrue(isUnavailable(r.putBack))
            XCTAssertFalse(r.insertBelow, "nothing incomplete is inserted")
        }
        let w = rec(capture(.word, .editable, .rich), op: .translate, finish: .truncated, canInsertBelow: true)
        XCTAssertEqual(w.enter, .copy)
        XCTAssertTrue(isUnavailable(w.putBack))
    }

    func testWordSpecialPlace() {
        let r = rec(capture(.word, .editable, .rich, wordCannotWrite: "In a footnote"))
        XCTAssertEqual(r.enter, .copy)
        XCTAssertEqual(r.putBack, .unavailable("In a footnote"))
    }

    func testLeftPanelOnClipboardPath() {
        let r = rec(capture(.clipboard, .unknown, .plain), leftPanel: true)
        XCTAssertEqual(r.enter, .copy)
        XCTAssertTrue(isUnavailable(r.putBack))
        // leaving the panel on the accessibility path does not block
        let ax = rec(capture(.accessibility, .editable, .plain), leftPanel: true)
        XCTAssertEqual(ax.enter, .replace)
        XCTAssertEqual(ax.putBack, .available([]))
    }

    func testWordTranslate() {
        let r = rec(capture(.word, .editable, .rich), op: .translate, canInsertBelow: true)
        XCTAssertEqual(r.enter, .insertBelow)
        XCTAssertTrue(isUnavailable(r.putBack))
        XCTAssertTrue(r.insertBelow)
        let noInsert = rec(capture(.word, .editable, .rich), op: .translate, canInsertBelow: false)
        XCTAssertEqual(noInsert.enter, .copy)
        XCTAssertTrue(isUnavailable(noInsert.putBack))
    }

    func testManualAndServiceCannotWrite() {
        XCTAssertTrue(isUnavailable(rec(capture(.manual, .editable, .plain)).putBack))
        XCTAssertTrue(isUnavailable(rec(capture(.service, .editable, .plain)).putBack))
    }

    func testRule1BeatsFailedChecks() {
        let r = rec(capture(.accessibility, .readOnly, .plain), checks: failedChecks())
        XCTAssertTrue(isUnavailable(r.putBack))
    }

    // MARK: rule 2 — failed checks

    func testFailedChecksCopyAndConfirm() {
        let r = rec(capture(.accessibility, .editable, .plain), checks: failedChecks())
        XCTAssertEqual(r.enter, .copy)
        guard let cs = confirms(r.putBack) else { return XCTFail("⌘⏎ must stay available") }
        XCTAssertEqual(cs.count, 1)
        guard case .failedChecks(let s) = cs[0] else { return XCTFail() }
        XCTAssertTrue(s.contains("müssen"))
        XCTAssertTrue(r.confirmText?.hasPrefix("Checks failed: ") ?? false)
    }

    func testFailedChecksInWord() {
        let r = rec(capture(.word, .editable, .rich), checks: failedChecks())
        XCTAssertEqual(r.enter, .copy)
        XCTAssertEqual(confirms(r.putBack)?.count, 1)
    }

    func testFailedChecksMergeWithOtherConfirmations() {
        let r = rec(capture(.clipboard, .unknown, .rich, formatting: 2), checks: failedChecks(), multiline: true)
        XCTAssertEqual(r.enter, .copy)
        let cs = confirms(r.putBack) ?? []
        XCTAssertEqual(cs.count, 3)
        XCTAssertTrue(cs.contains(.multilinePaste))
        XCTAssertTrue(cs.contains(.losesFormatting(2)))
        let text = r.confirmText ?? ""
        XCTAssertTrue(text.contains("Checks failed") && text.contains("several lines") && text.contains("2 formatted"), text)
    }

    // MARK: rule 3 — Word fix → tracked change

    func testWordFixIsTrackedChange() {
        for op in [TextOperation.fix, .polish, .tone] {
            let r = rec(capture(.word, .editable, .rich), profile: AppProfiles.profile(for: AppProfiles.word), op: op, canInsertBelow: true)
            XCTAssertEqual(r.enter, .trackedChange)
            XCTAssertEqual(r.putBack, .available([]), "no confirmation in Word")
            XCTAssertNil(r.confirmText)
        }
    }

    // MARK: rule 4 — unknown editability

    func testUnknownEditabilityCopies() {
        let r = rec(capture(.accessibility, .unknown, .plain))
        XCTAssertEqual(r.enter, .copy)
        XCTAssertEqual(r.putBack, .available([]))
        let m = rec(capture(.accessibility, .unknown, .plain), multiline: true)
        XCTAssertEqual(m.putBack, .available([.multilinePaste]))
    }

    func testAssumeEditableSkipsRule4ButKeepsMultilineConfirm() {
        var p = AppProfile(); p.assumeEditable = true; p.richText = .plain
        let r = rec(capture(.clipboard, .unknown, .unknown), profile: p, multiline: true)
        XCTAssertEqual(r.enter, .replace)
        XCTAssertEqual(r.putBack, .available([.multilinePaste]))
    }

    // MARK: rule 5 — rich text

    func testRichTextFixCopies() {
        let r = rec(capture(.accessibility, .editable, .rich, formatting: 3), canInsertBelow: true)
        XCTAssertEqual(r.enter, .copy)
        XCTAssertEqual(r.putBack, .available([.losesFormatting(3)]))
        let u = rec(capture(.accessibility, .editable, .unknown))
        XCTAssertEqual(u.enter, .copy)
        XCTAssertEqual(u.putBack, .available([.maybeLosesFormatting]), "unknown is treated as rich")
    }

    func testRichTextTranslateInsertsBelowOrCopies() {
        let pages = rec(capture(.accessibility, .editable, .rich), op: .translate, canInsertBelow: true)
        XCTAssertEqual(pages.enter, .insertBelow)
        XCTAssertTrue(pages.insertBelow)
        XCTAssertEqual(confirms(pages.putBack)?.count, 1)
        let mail = rec(capture(.accessibility, .editable, .rich), op: .translate, canInsertBelow: false)
        XCTAssertEqual(mail.enter, .copy)
    }

    func testProfileRichTextOverridesCapture() {
        var p = AppProfile(); p.richText = .plain
        XCTAssertEqual(rec(capture(.accessibility, .editable, .rich), profile: p).enter, .replace)
    }

    // MARK: rule 6 — plain editable

    func testPlainEditableReplaces() {
        let r = rec(capture(.accessibility, .editable, .plain))
        XCTAssertEqual(r.enter, .replace)
        XCTAssertEqual(r.putBack, .available([]))
        XCTAssertNil(r.confirmText)
        XCTAssertNil(r.enterReason)
        XCTAssertEqual(rec(capture(.accessibility, .editable, .plain), op: .translate).enter, .replace)
    }

    // MARK: §2.4 example

    func testGmailInChrome() throws {
        let profile = AppProfiles.profile(for: "com.google.Chrome")
        XCTAssertEqual(profile.reader, .clipboard)
        let r = rec(capture(.clipboard, .unknown, .rich, formatting: 1), profile: profile)
        XCTAssertEqual(r.enter, .copy, "rule 4 comes first")
        XCTAssertEqual(r.putBack, .available([.losesFormatting(1)]))
        let text = try XCTUnwrap(r.confirmText)
        XCTAssertTrue(text.contains("1 formatted item"), text)
        XCTAssertFalse(text.contains("; "), "one confirmation, one sentence")
        // translate in Gmail: copy, no insert-below on the clipboard path
        XCTAssertEqual(rec(capture(.clipboard, .unknown, .rich, formatting: 1), profile: profile, op: .translate).enter, .copy)
    }

    func testVSCodeIsCopyWithPutBack() {
        let p = AppProfiles.profile(for: "com.microsoft.VSCode")
        let r = rec(capture(.clipboard, .unknown, .unknown), profile: p)
        XCTAssertEqual(r.enter, .copy)
        XCTAssertEqual(r.putBack, .available([]), "plain-text app: no formatting warning")
    }
}
