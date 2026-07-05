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
    ),
    TestCase(
        name: "MarqueeTextEngineTests.testLongTextWithPausesHoldsAtStartAndEnd",
        run: MarqueeTextEngineTests.testLongTextWithPausesHoldsAtStartAndEnd
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

    static func testLongTextWithPausesHoldsAtStartAndEnd() throws {
        let start = MarqueeTextEngine.pausedFrame(
            text: "abcdefghij",
            visibleCharacterCount: 4,
            tick: 1,
            leadingPauseTicks: 2,
            trailingPauseTicks: 2
        )
        let moving = MarqueeTextEngine.pausedFrame(
            text: "abcdefghij",
            visibleCharacterCount: 4,
            tick: 2,
            leadingPauseTicks: 2,
            trailingPauseTicks: 2
        )
        let end = MarqueeTextEngine.pausedFrame(
            text: "abcdefghij",
            visibleCharacterCount: 4,
            tick: 8,
            leadingPauseTicks: 2,
            trailingPauseTicks: 2
        )
        let wrapped = MarqueeTextEngine.pausedFrame(
            text: "abcdefghij",
            visibleCharacterCount: 4,
            tick: 10,
            leadingPauseTicks: 2,
            trailingPauseTicks: 2
        )

        try expectEqual(start, MarqueeFrame(text: "abcd", isScrolling: true))
        try expectEqual(moving, MarqueeFrame(text: "bcde", isScrolling: true))
        try expectEqual(end, MarqueeFrame(text: "ghij", isScrolling: true))
        try expectEqual(wrapped, MarqueeFrame(text: "abcd", isScrolling: true))
    }
}
