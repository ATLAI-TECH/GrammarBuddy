import XCTest
@testable import GrammarBuddyKit

final class CleanerTests: XCTestCase {
    func testPreambleRemoved() {
        let o = "Their are many reasons."
        XCTAssertEqual(Cleaner.clean("Here is the corrected text:\n\nThere are many reasons.", original: o, operation: .fix),
                       "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("Sure! Here's the corrected version:\nThere are many reasons.", original: o, operation: .fix),
                       "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("Corrected text:\nThere are many reasons.", original: o, operation: .fix),
                       "There are many reasons.")
        // a normal first line ending in a colon is not a preamble
        let list = "Ingredients:\n- flour\n- eggs"
        XCTAssertEqual(Cleaner.clean(list, original: list, operation: .fix), list)
    }

    func testThinkRemoved() {
        let o = "Their are many reasons."
        XCTAssertEqual(Cleaner.clean("<think>The user wants a fix.\nOK.</think>\n\nThere are many reasons.", original: o, operation: .fix),
                       "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("<think>a</think>There are <think>b</think>many reasons.", original: o, operation: .fix),
                       "There are many reasons.")
        // unterminated thinking (truncated stream): drop from <think> on
        XCTAssertEqual(Cleaner.clean("There are many reasons.<think>hmm", original: o, operation: .fix),
                       "There are many reasons.")
    }

    func testWrappingQuotesStrippedOnlyWhenOriginalHasNone() {
        let o = "Their are many reasons."
        XCTAssertEqual(Cleaner.clean("\"There are many reasons.\"", original: o, operation: .fix), "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("“There are many reasons.”", original: o, operation: .fix), "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("「There are many reasons.」", original: o, operation: .fix), "There are many reasons.")
        XCTAssertEqual(Cleaner.clean("```\nThere are many reasons.\n```", original: o, operation: .fix), "There are many reasons.")
        // original quoted: keep
        let q = "\"Their are many reasons.\""
        XCTAssertEqual(Cleaner.clean("\"There are many reasons.\"", original: q, operation: .fix), "\"There are many reasons.\"")
        // inner quotes of the same kind: not a wrapping pair
        XCTAssertEqual(Cleaner.clean("\"Yes,\" she said, \"no.\"", original: "\"Yes,\" she said, \"no\"", operation: .fix),
                       "\"Yes,\" she said, \"no.\"")
        XCTAssertEqual(Cleaner.clean("\"Yes\" and \"no\"", original: "Yes and no", operation: .fix), "\"Yes\" and \"no\"")
    }

    func testGuillemetTranslationOfQuotedOriginalKept() {
        let o = "\"I will come tomorrow.\""
        XCTAssertEqual(Cleaner.clean("« Je viendrai demain. »", original: o, operation: .translate, targetLanguage: "fr"),
                       "«\u{00A0}Je viendrai demain.\u{00A0}»")
        XCTAssertEqual(Cleaner.clean("«Je viendrai demain.»", original: o, operation: .translate, targetLanguage: "fr"),
                       "«Je viendrai demain.»")
        XCTAssertEqual(Cleaner.clean("「明日行きます。」", original: o, operation: .translate, targetLanguage: "ja"), "「明日行きます。」")
        XCTAssertEqual(Cleaner.clean("“我明天来。”", original: o, operation: .translate, targetLanguage: "zh-Hans"), "“我明天来。”")
    }

    func testAddedEmphasisRemoved() {
        let o = "Arabidopsis thaliana plants with FLC mutations flower early."
        XCTAssertEqual(Cleaner.clean("*Arabidopsis thaliana* plants with **FLC** mutations flower early.", original: o, operation: .fix), o)
        XCTAssertEqual(Cleaner.clean("__Arabidopsis thaliana__ plants with FLC mutations flower early.", original: o, operation: .fix), o)
        // original already has emphasis: leave it
        let e = "*Arabidopsis thaliana* plants flower early."
        XCTAssertEqual(Cleaner.clean("*Arabidopsis thaliana* plants flower earlier.", original: e, operation: .fix),
                       "*Arabidopsis thaliana* plants flower earlier.")
        // a lone asterisk / multiplication is not emphasis
        XCTAssertEqual(Cleaner.clean("Use 2 * 3 rows.", original: "Use 2 * 3 row.", operation: .fix), "Use 2 * 3 rows.")
    }

    func testNBSPRestored() {
        let o = "It is 10\u{00A0}km away and costs 5\u{202F}€."
        XCTAssertEqual(Cleaner.clean("It is 10 km away and costs 5 €.", original: o, operation: .fix), o)
        let f = "Bonjour\u{202F}! Ça va\u{202F}?"
        XCTAssertEqual(Cleaner.clean("Bonjour ! Ça va ?", original: f, operation: .fix), f)
        // nothing to restore when the original has none
        XCTAssertEqual(Cleaner.clean("It is 10 km away.", original: "It is 10 km away", operation: .fix), "It is 10 km away.")
        // not for translations
        XCTAssertEqual(Cleaner.clean("Es ist 10 km entfernt.", original: "It is 10\u{00A0}km away.", operation: .translate, targetLanguage: "de"),
                       "Es ist 10 km entfernt.")
    }

    func testFrenchSpacingAfterTranslation() {
        let out = Cleaner.clean("Il a dit : « Viens ! » Pourquoi ? Oui ; non.", original: "He said: \"Come!\" Why? Yes; no.",
                                operation: .translate, targetLanguage: "fr")
        XCTAssertEqual(out, "Il a dit\u{202F}: «\u{00A0}Viens\u{202F}!\u{00A0}» Pourquoi\u{202F}? Oui\u{202F}; non.")
        // only existing plain spaces are replaced; no space is added
        XCTAssertEqual(Cleaner.clean("Pourquoi?", original: "Why?", operation: .translate, targetLanguage: "fr-CA"), "Pourquoi?")
        // not for other target languages
        XCTAssertEqual(Cleaner.clean("Warum ?", original: "Why?", operation: .translate, targetLanguage: "de"), "Warum ?")
        // not for fixes
        XCTAssertEqual(Cleaner.clean("Pourquoi ?", original: "Pourquoi ?", operation: .fix), "Pourquoi ?")
    }
}
