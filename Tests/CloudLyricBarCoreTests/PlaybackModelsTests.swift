import CloudLyricBarCore

struct PlaybackModelsTests {
    static func runAll() {
        testMenuBarTitleUsesLyricWhenPlaying()
        testMenuBarTitleFallsBackToSongTitleWhenLyricMissing()
        testMenuBarTitleShowsIdleWhenClientIsClosed()
    }

    static func testMenuBarTitleUsesLyricWhenPlaying() {
        let state = MenuBarDisplayState(
            isClientRunning: true,
            playback: .playing,
            lyricText: "在云端轻轻唱",
            fallbackTitle: "晴天"
        )

        expect(state.title == "♪ 在云端轻轻唱", "Expected title to use current lyric")
        expect(state.shouldAnimate, "Expected lyric state to animate while playing")
    }

    static func testMenuBarTitleFallsBackToSongTitleWhenLyricMissing() {
        let state = MenuBarDisplayState(
            isClientRunning: true,
            playback: .playing,
            lyricText: nil,
            fallbackTitle: "晴天"
        )

        expect(state.title == "♪ 晴天", "Expected title to fall back to song title")
        expect(!state.shouldAnimate, "Expected missing lyric state not to animate")
    }

    static func testMenuBarTitleShowsIdleWhenClientIsClosed() {
        let state = MenuBarDisplayState(
            isClientRunning: false,
            playback: .playing,
            lyricText: "在云端轻轻唱",
            fallbackTitle: "晴天"
        )

        expect(state.title == "♪", "Expected idle title when client is closed")
        expect(!state.shouldAnimate, "Expected closed client state not to animate")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }
}
