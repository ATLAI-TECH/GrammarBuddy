import XCTest
@testable import GrammarBuddyKit

final class WordDiffTests: XCTestCase {
    private func roundTrip(_ a: String, _ b: String, file: StaticString = #filePath, line: UInt = #line) {
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertEqual(WordDiff.apply(cs, to: a), b, "round trip", file: file, line: line)
        var none = cs
        for k in none.indices { none[k].accepted = false }
        XCTAssertEqual(WordDiff.apply(none, to: a), a, "reject all", file: file, line: line)
        let ns = a as NSString
        for c in cs {
            XCTAssertLessThanOrEqual(NSMaxRange(c.range), ns.length, file: file, line: line)
            XCTAssertEqual(ns.substring(with: c.range), c.removed, "range matches removed text", file: file, line: line)
        }
    }

    func testSingleReplacement() {
        let a = "Their are many reasons.", b = "There are many reasons."
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertEqual(cs.count, 1)
        XCTAssertEqual(cs[0].removed, "Their")
        XCTAssertEqual(cs[0].inserted, "There")
        XCTAssertEqual(cs[0].range, NSRange(location: 0, length: 5))
        XCTAssertEqual(cs[0].kind, .replace)
        XCTAssertEqual(cs[0].label, "Their → There")
        roundTrip(a, b)
    }

    func testIdenticalTextHasNoChanges() {
        XCTAssertTrue(WordDiff.changes(from: "Nothing to fix here.", to: "Nothing to fix here.").isEmpty)
        XCTAssertTrue(WordDiff.changes(from: "", to: "").isEmpty)
    }

    func testInsertAndDelete() {
        roundTrip("I went store.", "I went to the store.")
        roundTrip("This is is a test.", "This is a test.")
        let ins = WordDiff.changes(from: "I went store.", to: "I went to the store.")
        XCTAssertTrue(ins.contains { $0.kind == .insert })
        let del = WordDiff.changes(from: "This is is a test.", to: "This is a test.")
        XCTAssertTrue(del.contains { $0.kind == .delete })
    }

    func testMultipleChangesRoundTripAndRejectOne() {
        let a = "Their are three sample in the the lab on friday."
        let b = "There are three samples in the lab on Friday."
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertGreaterThanOrEqual(cs.count, 3)
        roundTrip(a, b)
        // ids are sequential after merging
        XCTAssertEqual(cs.map(\.id), Array(0..<cs.count))
        // reject the first change only: everything else applies, the first stays original
        var rejected = cs
        rejected[0].accepted = false
        let out = WordDiff.apply(rejected, to: a)
        XCTAssertTrue(out.hasPrefix("Their are"), out)
        XCTAssertTrue(out.contains("samples"), out)
        XCTAssertTrue(out.contains("Friday"), out)
        XCTAssertFalse(out.contains("the the"), out)
        // reject the last change only
        var lastRejected = cs
        lastRejected[cs.count - 1].accepted = false
        let out2 = WordDiff.apply(lastRejected, to: a)
        XCTAssertTrue(out2.hasPrefix("There are"), out2)
        XCTAssertTrue(out2.contains("friday"), out2)
    }

    func testChineseRoundTrip() {
        let a = "我们昨天去学校，这于前人的报道一至。"
        let b = "我们昨天去学校，这与前人的报道一致。"
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertFalse(cs.isEmpty)
        // word-level, not the whole sentence
        XCTAssertTrue(cs.allSatisfy { $0.removed.count < a.count / 2 })
        roundTrip(a, b)
    }

    func testJapaneseRoundTrip() {
        roundTrip("私は昨日学校へ行きました。", "私は今日学校に行きました。")
        roundTrip("これはペンです。", "これは本です。")
    }

    func testEmojiUTF16Offsets() {
        let a = "I 👍 this pakage a lot."
        let b = "I 👍 this package a lot."
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertEqual(cs.count, 1)
        // "I " = 2, 👍 = 2 UTF-16 units, " this " = 6 → 10
        XCTAssertEqual(cs[0].range, NSRange(location: 10, length: 6))
        XCTAssertEqual(cs[0].removed, "pakage")
        XCTAssertEqual(cs[0].inserted, "package")
        roundTrip(a, b)
        // emoji inside changed region, and family emoji (several scalars)
        roundTrip("Great job 👨‍👩‍👧 tem!", "Great job 👨‍👩‍👧 team!")
        roundTrip("😀 Their is 🎉 a party", "😀 There is 🎉 a party")
    }

    func testWhitespaceChanges() {
        let a = "Hello  world.", b = "Hello world."
        let cs = WordDiff.changes(from: a, to: b)
        XCTAssertEqual(cs.count, 1)
        XCTAssertEqual(cs[0].removed, "  ")
        XCTAssertEqual(cs[0].inserted, " ")
        XCTAssertEqual(cs[0].label, "␣␣ → ␣")
        roundTrip(a, b)
        roundTrip("A line.\nNext line.", "A line. Next line.")
        roundTrip("10 km", "10\u{00A0}km")
        let nb = WordDiff.changes(from: "10 km", to: "10\u{00A0}km")
        XCTAssertEqual(nb.first?.label, "␣ → ⍽")
        // punctuation-only change
        roundTrip("Hello world", "Hello, world")
        roundTrip("Cuando vienes?", "¿Cuándo vienes?")
    }

    func testVisibleWhitespace() {
        XCTAssertEqual(" \u{00A0}\u{202F}\n\t".visibleWhitespace, "␣⍽⍽↵⇥")
    }

    func testGermanReorderRoundTrip() {
        roundTrip("Ich denke das wir müssen noch einige änderungen machen bevor wir es einreichen.",
                  "Ich denke, dass wir noch einige Änderungen machen müssen, bevor wir es einreichen.")
    }
}
