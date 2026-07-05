import CloudLyricBarCore
import Foundation

let playbackControlServiceTests: [TestCase] = [
    TestCase(
        name: "PlaybackControlServiceTests.testUsesFirstStrategyThatCanHandleCommand",
        run: PlaybackControlServiceTests.testUsesFirstStrategyThatCanHandleCommand
    ),
    TestCase(
        name: "PlaybackControlServiceTests.testThrowsWhenNoStrategyCanHandleCommand",
        run: PlaybackControlServiceTests.testThrowsWhenNoStrategyCanHandleCommand
    ),
    TestCase(
        name: "PlaybackControlServiceTests.testNetEaseDeepLinkStrategyOpensSongURL",
        run: PlaybackControlServiceTests.testNetEaseDeepLinkStrategyOpensSongURL
    )
]

enum PlaybackControlServiceTests {
    static func testUsesFirstStrategyThatCanHandleCommand() async throws {
        let first = RecordingPlaybackControlStrategy(canSendResult: false)
        let second = RecordingPlaybackControlStrategy(canSendResult: true)
        let service = PlaybackControlService(strategies: [first, second])

        try await service.send(.playPause)

        try await expectEqual(first.sentCommands(), [])
        try await expectEqual(second.sentCommands(), [.playPause])
    }

    static func testThrowsWhenNoStrategyCanHandleCommand() async throws {
        let service = PlaybackControlService(
            strategies: [
                RecordingPlaybackControlStrategy(canSendResult: false),
                RecordingPlaybackControlStrategy(canSendResult: false)
            ]
        )

        do {
            try await service.send(.next)
            throw TestFailure(message: "Expected noAvailableStrategy error")
        } catch let error as PlaybackControlError {
            try expectEqual(error, .noAvailableStrategy)
        }
    }

    static func testNetEaseDeepLinkStrategyOpensSongURL() async throws {
        let recorder = URLRecorder()
        let strategy = NetEaseDeepLinkStrategy(opener: recorder.record)

        try await expectTrue(strategy.canSend(.openSong(id: "1901371647")))
        try await expectFalse(strategy.canSend(.playPause))
        try await strategy.send(.openSong(id: "1901371647"))

        try expectEqual(recorder.recordedURLs(), [URL(string: "orpheus://song/1901371647")!])

        do {
            try await strategy.send(.playPause)
            throw TestFailure(message: "Expected noAvailableStrategy error")
        } catch let error as PlaybackControlError {
            try expectEqual(error, .noAvailableStrategy)
        }
    }
}

private actor RecordingPlaybackControlStrategy: PlaybackControlStrategy {
    private let canSendResult: Bool
    private var commands: [PlaybackCommand] = []

    init(canSendResult: Bool) {
        self.canSendResult = canSendResult
    }

    func canSend(_ command: PlaybackCommand) async -> Bool {
        canSendResult
    }

    func send(_ command: PlaybackCommand) async throws {
        commands.append(command)
    }

    func sentCommands() -> [PlaybackCommand] {
        commands
    }
}

private final class URLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func record(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        urls.append(url)
    }

    func recordedURLs() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}
