import XCTest
@testable import GrammarBuddyKit

/// Behaviour added after review rounds 5 and 6.
final class Round56Tests: XCTestCase {
    func testPolishIntoEnglishIsCaught() {
        let zh = "付款方应在收到发票后三十日内支付全部款项，逾期每日按未付金额的万分之五支付违约金。"
        let en = "The paying party shall pay the full amount within thirty days of receiving the invoice."
        let c = Checks.run(original: zh, result: en, operation: .polish)
        XCTAssertNotNil(c.languageChanged)
        XCTAssertTrue(c.failed)
        let ja = "明日の会議ですが、資料は私が準備しておきます。よろしくお願いします。"
        XCTAssertNotNil(Checks.run(original: ja, result: "I will prepare the materials for tomorrow's meeting.", operation: .tone).languageChanged)
    }

    func testSameLanguageIsFine() {
        let c = Checks.run(original: "Ich habe gestern den Bericht gelesen und denke das wir müssen.", result: "Ich habe gestern den Bericht gelesen und denke, dass wir müssen.", operation: .fix)
        XCTAssertNil(c.languageChanged)
    }

    func testLanguageChangeBlocksPutBack() {
        var cap = Capture(raw: "付款方应在收到发票后三十日内支付全部款项。", via: .accessibility, editability: .editable, richText: .plain, range: NSRange(location: 0, length: 5))
        cap.app = TargetApp(bundleID: "com.apple.TextEdit", name: "TextEdit", pid: 1)
        var checks = CheckResult(); checks.languageChanged = "English"
        let r = recommend(RecommendInput(capture: cap, profile: AppProfile(), operation: .polish, checks: checks, finish: .complete,
                                         leftPanel: false, resultIsMultiline: false, canInsertBelow: false))
        guard case .unavailable = r.putBack else { return XCTFail("put back must be unavailable") }
        XCTAssertEqual(r.enter, .copy)
    }

    func testAddedCitationIsCaught() {
        let c = Checks.run(original: "¡Trae a tus amigos!", result: "¡Lleva a tus amigos [12]!", operation: .translate)
        XCTAssertEqual(c.addedCitations, ["[12]"])
    }

    func testScaleWordsInTranslation() {
        // 1.400 millones = 1.4 billion: correct, no hint
        XCTAssertTrue(Checks.run(original: "asciende a 1.400 millones de euros", result: "amounts to 1.4 billion euros", operation: .translate,
                                 sourceLanguage: "es", targetLanguage: "en").numberMismatch.isEmpty)
        // "1.400 million" in English is 1.4 million: wrong by 1000×
        XCTAssertFalse(Checks.run(original: "asciende a 1.400 millones de euros", result: "amounts to 1.400 million euros", operation: .translate,
                                  sourceLanguage: "es", targetLanguage: "en").numberMismatch.isEmpty)
    }

    func testNumberMismatchMakesEnterCopy() {
        var cap = Capture(raw: "1.400 millones", via: .accessibility, editability: .editable, richText: .rich, range: NSRange(location: 0, length: 3))
        cap.app = TargetApp(bundleID: "com.apple.iWork.Pages", name: "Pages", pid: 1)
        var checks = CheckResult(); checks.numberMismatch = ["1.400"]
        let r = recommend(RecommendInput(capture: cap, profile: AppProfile(), operation: .translate, checks: checks, finish: .complete,
                                         leftPanel: false, resultIsMultiline: false, canInsertBelow: true))
        XCTAssertEqual(r.enter, .copy)
    }

    func testTrailingMarkdownSpacesAreRemoved() {
        XCTAssertEqual(Cleaner.clean("- one  \n- two", original: "- one\n- two", operation: .fix), "- one\n- two")
    }

    func testLanguageNamedInPrompt() {
        let s = Prompts.system(for: .polish, sourceLanguage: "Japanese")
        XCTAssertTrue(s.hasPrefix("The text is written in Japanese."))
        XCTAssertFalse(Prompts.system(for: .translate, target: "French", sourceLanguage: "Japanese").contains("written in Japanese"))
    }
}

/// Round 7.
final class Round7Tests: XCTestCase {
    func testQuoteRanges() {
        let s = "El alcalde dijo: «No vamos a explicarnos na» y se fue."
        let q = Quotes.ranges(in: s)
        XCTAssertEqual(q.count, 1)
        let na = (s as NSString).range(of: "na»")
        XCTAssertTrue(Quotes.contains(NSRange(location: na.location, length: 2), in: q))
        XCTAssertFalse(Quotes.contains((s as NSString).range(of: "alcalde"), in: q))
        XCTAssertEqual(Quotes.ranges(in: "She said \"we is ready\" and left.").count, 1)
        XCTAssertEqual(Quotes.ranges(in: "—¿Cuanto cuesta? —preguntó.\nNada más.").count, 1)
    }

    func testAdjacentEditsAreOneChange() {
        let cs = WordDiff.changes(from: "no pudo llegar por que la carretera estaba cortada", to: "no pudo llegar porque la carretera estaba cortada")
        XCTAssertEqual(cs.count, 1)
        XCTAssertEqual(WordDiff.apply(cs, to: "no pudo llegar por que la carretera estaba cortada"), "no pudo llegar porque la carretera estaba cortada")
    }

    func testRedundantComparativeIsNotADroppedWord() {
        XCTAssertEqual(Checks.droppedWords(original: "The yield was more higher than before.", result: "The yield was higher than before."), [])
    }

    func testFullWidthCitationIsNotAdded() {
        let c = Checks.run(original: "这与前人的报道一致（Smith et al., 2020）。", result: "This agrees with earlier reports (Smith et al., 2020).", operation: .translate)
        XCTAssertEqual(c.addedCitations, [])
    }

    func testVersionNumberIsNotAMismatch() {
        XCTAssertEqual(Checks.run(original: "We released Notula 2.0 last week.", result: "Nous avons publié Notula 2.0 la semaine dernière.", operation: .translate,
                                  sourceLanguage: "en", targetLanguage: "fr").numberMismatch, [])
    }
}

final class Round8Tests: XCTestCase {
    func testRemovedRepetitionIsNotADroppedWord() {
        XCTAssertEqual(Checks.droppedWords(original: "Las obras van a empezar a empezar el lunes.", result: "Las obras van a empezar el lunes."), [])
        XCTAssertEqual(Checks.droppedWords(original: "We saw the the result.", result: "We saw the result."), [])
        XCTAssertFalse(Checks.droppedWords(original: "denke das wir müssen noch Änderungen machen", result: "denke, dass wir noch Änderungen machen").isEmpty)
    }
}

extension Round8Tests {
    func testTimesAndSpelledOutNumbers() {
        XCTAssertEqual(Checks.run(original: "La réunion est à 14h30.", result: "The meeting is at 2:30 pm.", operation: .translate,
                                  sourceLanguage: "fr", targetLanguage: "en").numberMismatch, [])
        XCTAssertEqual(Checks.run(original: "Il y a 8 personnes.", result: "There are eight people.", operation: .translate,
                                  sourceLanguage: "fr", targetLanguage: "en").numberMismatch, [])
        XCTAssertFalse(Checks.run(original: "J'ai 3 chats.", result: "I have 4 cats.", operation: .translate,
                                  sourceLanguage: "fr", targetLanguage: "en").numberMismatch.isEmpty)
    }
}
