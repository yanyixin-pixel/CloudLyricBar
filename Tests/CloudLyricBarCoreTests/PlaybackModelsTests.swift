import CloudLyricBarCore

let playbackModelTests: [TestCase] = [
    TestCase(
        name: "PlaybackModelsTests.testMenuBarTitleUsesLyricWhenPlaying",
        run: PlaybackModelsTests.testMenuBarTitleUsesLyricWhenPlaying
    ),
    TestCase(
        name: "PlaybackModelsTests.testMenuBarTitleFallsBackToSongTitleWhenLyricMissing",
        run: PlaybackModelsTests.testMenuBarTitleFallsBackToSongTitleWhenLyricMissing
    ),
    TestCase(
        name: "PlaybackModelsTests.testMenuBarTitleFallsBackWhenLyricIsEmpty",
        run: PlaybackModelsTests.testMenuBarTitleFallsBackWhenLyricIsEmpty
    ),
    TestCase(
        name: "PlaybackModelsTests.testMenuBarTitleShowsIdleWhenClientIsClosed",
        run: PlaybackModelsTests.testMenuBarTitleShowsIdleWhenClientIsClosed
    ),
    TestCase(
        name: "PlaybackModelsTests.testMenuBarTitleFrameScrollsLongPlayingLyric",
        run: PlaybackModelsTests.testMenuBarTitleFrameScrollsLongPlayingLyric
    )
]

enum PlaybackModelsTests {
    static func testMenuBarTitleUsesLyricWhenPlaying() throws {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: "在云端轻轻唱",
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        try expectEqual(state.title, "♪ 在云端轻轻唱")
        try expectTrue(state.shouldAnimate)
    }

    static func testMenuBarTitleFallsBackToSongTitleWhenLyricMissing() throws {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: nil,
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        try expectEqual(state.title, "♪ 晴天")
        try expectFalse(state.shouldAnimate)
    }

    static func testMenuBarTitleFallsBackWhenLyricIsEmpty() throws {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: "   ",
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        try expectEqual(state.title, "♪ 晴天")
        try expectFalse(state.shouldAnimate)
    }

    static func testMenuBarTitleShowsIdleWhenClientIsClosed() throws {
        let state = MenuBarDisplayState(
            playback: .stopped,
            lyricText: nil,
            fallbackTitle: nil,
            isClientRunning: false
        )

        try expectEqual(state.title, "♪")
        try expectFalse(state.shouldAnimate)
    }

    static func testMenuBarTitleFrameScrollsLongPlayingLyric() throws {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: "这是一句非常非常长的歌词需要在系统栏里滚动显示",
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        let frame = state.marqueeFrame(visibleCharacterCount: 10, tick: 3)

        try expectEqual(frame.text.count, 10)
        try expectTrue(frame.isScrolling)
        try expectEqual(frame.text, "是一句非常非常长的歌")
    }
}
