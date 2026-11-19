import XCTest
@testable import GrammarBuddyKit

/// The direction chosen for hard cases, for a user whose languages are Chinese and English. "?" = either is fine.
final class DirectionProbe: XCTestCase {
    func testDirectionForChineseEnglishUser() {
        let mine = ["zh-Hans", "en"]
        let cases: [(String, String)] = [
            ("我们的实验结果表明，这种方法更好。", "en"),
            ("The results were consistent across all three experiments.", "zh"),
            ("我们用 PCR 和 Western blot 验证了 FLC 基因的表达。", "en"),
            ("这个 bug 是因为 AXEnhancedUserInterface 没有打开，需要在 Word 里先 set 一下 flag。", "en"),
            ("Please review 这个文档 before Friday, thanks.", "zh"),
            ("OK", "zh"), ("好的", "en"), ("谢谢！", "en"), ("Thanks!", "zh"), ("deadline", "zh"), ("开会", "en"),
            ("GrammarBuddy 0.1.0", "zh"), ("2026-11-19 10:30", "?"), ("https://github.com/ATLAI-TECH/GrammarBuddy", "?"),
            ("Hi 王老师，附件是修改后的稿子，请查收。", "en"),
            ("Dear Prof. Wang, 附件是修改稿。Best regards, Li", "?"),
            ("flc-3 突变体在长日照下比 Col-0 开花更早", "en"),
            ("RNA-seq", "zh"), ("def main(): return 0", "?"),
            ("El Ayuntamiento aprobó ayer el nuevo presupuesto.", "zh"),
            ("実験結果は以前の報告と一致した。", "zh"),
            ("我们在會議上討論了這個問題。", "?"),      // Traditional → Simplified unless the user chose otherwise (§2.5)
            ("Yes, 可以。", "en"), ("I think 这个方案 is better because 成本更低 and it scales.", "zh"),
        ]
        for (t, want) in cases {
            let d = LanguageDirection.detect(t, preferred: mine)
            let src = d.language ?? "nil"
            let tgt = d.language.map { LanguageDirection.target(source: $0, mine: mine, lastTargets: [:]) } ?? "-"
            let ok = want == "?" ? " " : (tgt.hasPrefix(want) ? "✓" : "✗")
            if want != "?" { XCTAssertTrue(tgt.hasPrefix(want), "\(t) → \(src) → \(tgt), wanted \(want)") }
            if want != "?" { XCTAssertTrue(d.confident, "\(t): should not need to ask") }
            print("DIR \(ok) \(src.padding(toLength: 8, withPad: " ", startingAt: 0)) → \(tgt.padding(toLength: 8, withPad: " ", startingAt: 0)) confident=\(d.confident ? "yes" : "NO ")  | \(t.prefix(60))")
        }
    }
}
