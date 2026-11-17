import XCTest
@testable import GrammarBuddyKit

final class LanguageDirectionTests: XCTestCase {
    func testFirstAndSecondAreFixed() {
        let mine = ["zh-Hans", "en"]
        XCTAssertEqual(LanguageDirection.target(source: "zh-Hans", mine: mine, lastTargets: [:]), "en")
        XCTAssertEqual(LanguageDirection.target(source: "zh", mine: mine, lastTargets: [:]), "en")
        XCTAssertEqual(LanguageDirection.target(source: "en", mine: mine, lastTargets: [:]), "zh-Hans")
        XCTAssertEqual(LanguageDirection.target(source: "en-GB", mine: mine, lastTargets: [:]), "zh-Hans")
        // last targets never override the fixed pair
        XCTAssertEqual(LanguageDirection.target(source: "en", mine: mine, lastTargets: ["en": "fr"]), "zh-Hans")
    }

    func testOtherLanguagesUseLastTargetOrFirst() {
        let mine = ["de", "en-GB", "fr"]
        XCTAssertEqual(LanguageDirection.target(source: "fr", mine: mine, lastTargets: [:]), "de")
        XCTAssertEqual(LanguageDirection.target(source: "es", mine: mine, lastTargets: [:]), "de")
        XCTAssertEqual(LanguageDirection.target(source: "es", mine: mine, lastTargets: ["es": "en-GB"]), "en-GB")
        XCTAssertEqual(LanguageDirection.target(source: "en-US", mine: mine, lastTargets: [:]), "de")
    }

    func testTraditionalChineseIsSeparate() {
        let mine = ["zh-Hans", "en"]
        XCTAssertEqual(LanguageDirection.target(source: "zh-Hant", mine: mine, lastTargets: [:]), "zh-Hans")
        XCTAssertEqual(LanguageDirection.target(source: "zh-Hant", mine: mine, lastTargets: ["zh-Hant": "en"]), "en")
    }

    func testDetect() {
        let en = LanguageDirection.detect("The quick brown fox jumps over the lazy dog near the river bank today.")
        XCTAssertEqual(en.language, "en")
        XCTAssertTrue(en.confident)
        XCTAssertFalse(LanguageDirection.detect("Hi").confident, "short text asks first")
    }

    func testJoinHardWrapsSimilarLengths() {
        let s = "The results of the experiment show that the\nplants grown under long day conditions flowered\nmuch earlier than those grown under short days."
        XCTAssertEqual(LanguageDirection.joinHardWraps(s),
                       "The results of the experiment show that the plants grown under long day conditions flowered much earlier than those grown under short days.")
    }

    func testJoinHardWrapsHyphen() {
        let s = "We measured the expres-\nsion of FLC in all lines\nand found it was low."
        XCTAssertEqual(LanguageDirection.joinHardWraps(s), "We measured the expression of FLC in all lines and found it was low.")
    }

    func testJoinHardWrapsKeepsParagraphs() {
        let p = "The results of the experiment show that the\nplants grown under long day conditions flowered\nmuch earlier than those grown under short days."
        let out = LanguageDirection.joinHardWraps(p + "\n\n" + p)
        XCTAssertEqual(out.components(separatedBy: "\n\n").count, 2)
        XCTAssertFalse(out.components(separatedBy: "\n\n")[0].contains("\n"))
    }

    func testListLinesNotJoined() {
        let s = "Things to bring to the meeting tomorrow:\n- the signed contracts\n- the laptop charger\n1. print the slides\n2) book the room"
        XCTAssertEqual(LanguageDirection.joinHardWraps(s), s)
        let bullets = "• first bullet point here\n• second bullet point here\n• third bullet point here"
        XCTAssertEqual(LanguageDirection.joinHardWraps(bullets), bullets)
        let indented = "Here is the code we used for it\n  let x = computeTheValue()\n  let y = computeOtherOne()"
        XCTAssertEqual(LanguageDirection.joinHardWraps(indented), indented)
    }

    func testShortLinesOfDifferentLengthNotJoined() {
        let poem = "Roses are red\nViolets are blue and very lovely in spring\nSugar is sweet"
        XCTAssertEqual(LanguageDirection.joinHardWraps(poem), poem)
        let two = "Hello there\nGeneral Kenobi"
        XCTAssertEqual(LanguageDirection.joinHardWraps(two), two)
    }
}

final class DestinationTests: XCTestCase {
    func testThisMac() {
        XCTAssertEqual(Destination.classify("http://localhost:1234/v1"), .thisMac)
        XCTAssertEqual(Destination.classify("http://127.0.0.1:11434"), .thisMac)
        XCTAssertEqual(Destination.classify("http://127.0.1.1:8080"), .thisMac)
        XCTAssertEqual(Destination.classify("http://[::1]:1234/v1"), .thisMac)
        XCTAssertFalse(Destination.thisMac.leavesMac)
    }

    func testLocalNetwork() {
        XCTAssertEqual(Destination.classify("http://192.168.1.20:1234"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://10.0.0.5:11434"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://172.16.4.1"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://172.31.255.1"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://169.254.3.3"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://studio.local:1234"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://mac-studio:1234"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://[fe80::1]:1234"), .localNetwork)
        XCTAssertEqual(Destination.classify("http://[fd12:3456::1]:1234"), .localNetwork)
        XCTAssertTrue(Destination.localNetwork.leavesMac)
    }

    func testMyDevice() {
        // round 5 G5-09: Tailscale addresses are "my device" only when the user marks them
        XCTAssertEqual(Destination.classify("http://100.101.102.103:1234"), .internet)
        XCTAssertEqual(Destination.classify("http://studio.tail1234.ts.net:1234"), .internet)
        XCTAssertEqual(Destination.classify("http://studio.tail1234.ts.net:1234", myDevices: ["studio.tail1234.ts.net"]), .myDevice)
        XCTAssertEqual(Destination.classify("http://127.example.com/v1"), .internet)
        XCTAssertEqual(Destination.classify("http://127.0.0.1:1234"), .thisMac)
        XCTAssertEqual(Destination.classify("http://gpu.example.com/v1", myDevices: ["gpu.example.com"]), .myDevice)
    }

    func testInternet() {
        XCTAssertEqual(Destination.classify("https://api.openai.com/v1"), .internet)
        XCTAssertEqual(Destination.classify("https://api.anthropic.com"), .internet)
        XCTAssertEqual(Destination.classify("http://172.32.0.1"), .internet)
        XCTAssertEqual(Destination.classify("http://8.8.8.8"), .internet)
        XCTAssertEqual(Destination.classify("http://100.128.0.1"), .internet)
        XCTAssertEqual(Destination.classify("not a url"), .internet)
        // hostnames that merely start with "fd" are not IPv6 ULAs
        XCTAssertEqual(Destination.classify("https://fdic.gov/api"), .internet)
        // global IPv6 has no dots but is not local
        XCTAssertEqual(Destination.classify("http://[2606:4700::1111]/v1"), .internet)
    }
}

final class CaptureTests: XCTestCase {
    func testSplitKeepsLeadingAndTrailingWhitespace() {
        let (l, c, t) = Capture.split("  \n Their are many reasons.\n\n")
        XCTAssertEqual(l, "  \n ")
        XCTAssertEqual(c, "Their are many reasons.")
        XCTAssertEqual(t, "\n\n")
        XCTAssertEqual(l + c + t, "  \n Their are many reasons.\n\n")
    }

    func testSplitEdgeCases() {
        XCTAssertTrue(Capture.split("") == ("", "", ""))
        XCTAssertTrue(Capture.split("   ") == ("   ", "", ""))
        XCTAssertTrue(Capture.split("word") == ("", "word", ""))
        XCTAssertTrue(Capture.split("a b\tc") == ("", "a b\tc", ""))
        XCTAssertTrue(Capture.split("\r\nline\r\n") == ("\r\n", "line", "\r\n"))
        XCTAssertTrue(Capture.split("\u{3000}全角空格\u{3000}") == ("\u{3000}", "全角空格", "\u{3000}"))
        XCTAssertTrue(Capture.split("\u{00A0}x\u{00A0}") == ("\u{00A0}", "x", "\u{00A0}"))
        XCTAssertTrue(Capture.split(" 👍 ") == (" ", "👍", " "))
    }

    func testCaptureInit() {
        let c = Capture(raw: "\n  Hello world  \n", via: .accessibility)
        XCTAssertEqual(c.text, "Hello world")
        XCTAssertEqual(c.leading, "\n  ")
        XCTAssertEqual(c.trailing, "  \n")
        XCTAssertEqual(c.editability, .unknown)
        XCTAssertEqual(c.richText, .unknown)
        XCTAssertEqual(c.wordCount, 2)
    }
}

final class AppProfilesTests: XCTestCase {
    func testProfiles() {
        XCTAssertTrue(AppProfiles.profile(for: "com.apple.Terminal").readOnly)
        XCTAssertTrue(AppProfiles.profile(for: "com.1password.1password").excluded)
        XCTAssertEqual(AppProfiles.profile(for: "com.microsoft.Word").reader, .word)
        let slack = AppProfiles.profile(for: "com.tinyspeck.slackmacgap")
        XCTAssertEqual(slack.reader, .clipboard)
        XCTAssertEqual(slack.writer, .paste)
        let code = AppProfiles.profile(for: "com.microsoft.VSCode")
        XCTAssertEqual(code.richText, .plain)
        XCTAssertTrue(code.emptyCopyCopiesLine)
        XCTAssertEqual(AppProfiles.profile(for: "com.apple.TextEdit"), AppProfile())
        var o = AppProfile(); o.assumeEditable = true
        XCTAssertEqual(AppProfiles.profile(for: "com.tinyspeck.slackmacgap", overrides: ["com.tinyspeck.slackmacgap": o]), o)
    }
}
