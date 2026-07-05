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
        name: "PlaybackModelsTests.testMenuBarTitleShowsIdleWhenClientIsClosed",
        run: PlaybackModelsTests.testMenuBarTitleShowsIdleWhenClientIsClosed
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
}
