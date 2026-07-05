import XCTest
@testable import CloudLyricBarCore

final class PlaybackModelsTests: XCTestCase {
    func testMenuBarTitleUsesLyricWhenPlaying() {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: "在云端轻轻唱",
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        XCTAssertEqual(state.title, "♪ 在云端轻轻唱")
        XCTAssertTrue(state.shouldAnimate)
    }

    func testMenuBarTitleFallsBackToSongTitleWhenLyricMissing() {
        let state = MenuBarDisplayState(
            playback: .playing,
            lyricText: nil,
            fallbackTitle: "晴天",
            isClientRunning: true
        )

        XCTAssertEqual(state.title, "♪ 晴天")
        XCTAssertFalse(state.shouldAnimate)
    }

    func testMenuBarTitleShowsIdleWhenClientIsClosed() {
        let state = MenuBarDisplayState(
            playback: .stopped,
            lyricText: nil,
            fallbackTitle: nil,
            isClientRunning: false
        )

        XCTAssertEqual(state.title, "♪")
        XCTAssertFalse(state.shouldAnimate)
    }
}
