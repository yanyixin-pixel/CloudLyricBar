import CloudLyricBarCore

let marqueeTextEngineTests: [TestCase] = [
    TestCase(
        name: "MarqueeTextEngineTests.testShortTextDoesNotScroll",
        run: MarqueeTextEngineTests.testShortTextDoesNotScroll
    ),
    TestCase(
        name: "MarqueeTextEngineTests.testLongTextScrollsByTick",
        run: MarqueeTextEngineTests.testLongTextScrollsByTick
    ),
    TestCase(
        name: "MarqueeTextEngineTests.testLongTextWrapsWithSpacer",
        run: MarqueeTextEngineTests.testLongTextWrapsWithSpacer
    ),
    TestCase(
        name: "MarqueeTextEngineTests.testZeroVisibleCharacterCountReturnsEmptyFrame",
        run: MarqueeTextEngineTests.testZeroVisibleCharacterCountReturnsEmptyFrame
    )
]

enum MarqueeTextEngineTests {
    static func testShortTextDoesNotScroll() throws {
        let frame = MarqueeTextEngine.frame(text: "短歌词", visibleCharacterCount: 8, tick: 4)

        try expectEqual(frame, MarqueeFrame(text: "短歌词", isScrolling: false))
    }

    static func testLongTextScrollsByTick() throws {
        let frame = MarqueeTextEngine.frame(text: "abcdefghijklmnopqrstuvwxyz", visibleCharacterCount: 6, tick: 2)

        try expectEqual(frame, MarqueeFrame(text: "cdefgh", isScrolling: true))
    }

    static func testLongTextWrapsWithSpacer() throws {
        let frame = MarqueeTextEngine.frame(text: "abcdef", visibleCharacterCount: 4, tick: 7)

        try expectEqual(frame.text.count, 4)
        try expectTrue(frame.isScrolling)
    }

    static func testZeroVisibleCharacterCountReturnsEmptyFrame() throws {
        let frame = MarqueeTextEngine.frame(text: "abcdef", visibleCharacterCount: 0, tick: 2)

        try expectEqual(frame, MarqueeFrame(text: "", isScrolling: false))
    }
}
