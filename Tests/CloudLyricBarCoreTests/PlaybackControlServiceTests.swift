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
        name: "PlaybackControlServiceTests.testPropagatesStrategyCommandFailure",
        run: PlaybackControlServiceTests.testPropagatesStrategyCommandFailure
    ),
    TestCase(
        name: "PlaybackControlServiceTests.testNetEaseDeepLinkStrategyOpensSongURL",
        run: PlaybackControlServiceTests.testNetEaseDeepLinkStrategyOpensSongURL
    ),
    TestCase(
        name: "PlaybackControlServiceTests.testNetEaseDeepLinkStrategyRejectsInvalidSongIDs",
        run: PlaybackControlServiceTests.testNetEaseDeepLinkStrategyRejectsInvalidSongIDs
    ),
    TestCase(
        name: "PlaybackControlServiceTests.testConcurrentSendsCompleteInCallerOrder",
        run: PlaybackControlServiceTests.testConcurrentSendsCompleteInCallerOrder
    )
]

enum PlaybackControlServiceTests {
    static func testUsesFirstStrategyThatCanHandleCommand() async throws {
        let first = RecordingPlaybackControlStrategy(canSendResult: false)
        let second = RecordingPlaybackControlStrategy(canSendResult: true)
        let third = RecordingPlaybackControlStrategy(canSendResult: true)
        let service = PlaybackControlService(strategies: [first, second, third])

        try await service.send(.playPause)

        try await expectEqual(first.canSendCommands(), [.playPause])
        try await expectEqual(first.sentCommands(), [])
        try await expectEqual(second.canSendCommands(), [.playPause])
        try await expectEqual(second.sentCommands(), [.playPause])
        try await expectEqual(third.canSendCommands(), [])
        try await expectEqual(third.sentCommands(), [])
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

    static func testPropagatesStrategyCommandFailure() async throws {
        let service = PlaybackControlService(
            strategies: [
                FailingPlaybackControlStrategy(error: PlaybackControlError.commandFailed)
            ]
        )

        do {
            try await service.send(.playPause)
            throw TestFailure(message: "Expected commandFailed error")
        } catch let error as PlaybackControlError {
            try expectEqual(error, .commandFailed)
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

    static func testNetEaseDeepLinkStrategyRejectsInvalidSongIDs() async throws {
        let invalidIDs = ["123?x=y", "abc/def", "123#frag", ""]

        for id in invalidIDs {
            let recorder = URLRecorder()
            let strategy = NetEaseDeepLinkStrategy(opener: recorder.record)

            do {
                try await strategy.send(.openSong(id: id))
                throw TestFailure(message: "Expected noAvailableStrategy error for id \(id)")
            } catch let error as PlaybackControlError {
                try expectEqual(error, .noAvailableStrategy)
            }

            try expectEqual(recorder.recordedURLs(), [])
        }
    }

    static func testConcurrentSendsCompleteInCallerOrder() async throws {
        let strategy = DelayedRecordingPlaybackControlStrategy()
        let service = PlaybackControlService(strategies: [strategy])

        let first = Task {
            try await service.send(.previous)
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        let second = Task {
            try await service.send(.next)
        }

        try await first.value
        try await second.value

        try await expectEqual(strategy.completedCommands(), [.previous, .next])
    }
}

private actor RecordingPlaybackControlStrategy: PlaybackControlStrategy {
    private let canSendResult: Bool
    private var checkedCommands: [PlaybackCommand] = []
    private var commands: [PlaybackCommand] = []

    init(canSendResult: Bool) {
        self.canSendResult = canSendResult
    }

    func canSend(_ command: PlaybackCommand) async -> Bool {
        checkedCommands.append(command)
        return canSendResult
    }

    func send(_ command: PlaybackCommand) async throws {
        commands.append(command)
    }

    func sentCommands() -> [PlaybackCommand] {
        commands
    }

    func canSendCommands() -> [PlaybackCommand] {
        checkedCommands
    }
}

private actor DelayedRecordingPlaybackControlStrategy: PlaybackControlStrategy {
    private var commands: [PlaybackCommand] = []

    func canSend(_ command: PlaybackCommand) async -> Bool {
        true
    }

    func send(_ command: PlaybackCommand) async throws {
        if command == .previous {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        commands.append(command)
    }

    func completedCommands() -> [PlaybackCommand] {
        commands
    }
}

private struct FailingPlaybackControlStrategy: PlaybackControlStrategy {
    let error: PlaybackControlError

    func canSend(_ command: PlaybackCommand) async -> Bool {
        true
    }

    func send(_ command: PlaybackCommand) async throws {
        throw error
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
