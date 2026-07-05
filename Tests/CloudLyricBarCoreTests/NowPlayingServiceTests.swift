import CloudLyricBarCore
import Foundation

let nowPlayingServiceTests: [TestCase] = [
    TestCase(
        name: "NowPlayingServiceTests.testPlayingSnapshotAdvancesFromCaptureDate",
        run: NowPlayingServiceTests.testPlayingSnapshotAdvancesFromCaptureDate
    ),
    TestCase(
        name: "NowPlayingServiceTests.testPausedSnapshotDoesNotAdvance",
        run: NowPlayingServiceTests.testPausedSnapshotDoesNotAdvance
    ),
    TestCase(
        name: "NowPlayingServiceTests.testStoppedSnapshotDoesNotAdvance",
        run: NowPlayingServiceTests.testStoppedSnapshotDoesNotAdvance
    ),
    TestCase(
        name: "NowPlayingServiceTests.testNilPositionDoesNotAdvance",
        run: NowPlayingServiceTests.testNilPositionDoesNotAdvance
    ),
    TestCase(
        name: "NowPlayingServiceTests.testEarlierEstimateDateDoesNotReducePosition",
        run: NowPlayingServiceTests.testEarlierEstimateDateDoesNotReducePosition
    ),
    TestCase(
        name: "NowPlayingServiceTests.testSnapshotServiceReturnsEstimatedLatestSnapshot",
        run: NowPlayingServiceTests.testSnapshotServiceReturnsEstimatedLatestSnapshot
    ),
    TestCase(
        name: "NowPlayingServiceTests.testExternalNowPlayingPayloadAdvancesElapsedTimeFromTimestamp",
        run: NowPlayingServiceTests.testExternalNowPlayingPayloadAdvancesElapsedTimeFromTimestamp
    )
]

enum NowPlayingServiceTests {
    static func testPlayingSnapshotAdvancesFromCaptureDate() throws {
        let snapshot = NowPlayingSnapshot(
            song: sampleSong,
            playback: .playing,
            position: 10,
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let estimated = TimerPositionEstimator.estimate(
            from: snapshot,
            at: Date(timeIntervalSince1970: 104.25)
        )

        try expectEqual(estimated.position, 14.25)
        try expectEqual(estimated.capturedAt, Date(timeIntervalSince1970: 104.25))
        try expectEqual(estimated.song, sampleSong)
        try expectEqual(estimated.playback, .playing)
    }

    static func testPausedSnapshotDoesNotAdvance() throws {
        let snapshot = NowPlayingSnapshot(
            song: sampleSong,
            playback: .paused,
            position: 10,
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let estimated = TimerPositionEstimator.estimate(
            from: snapshot,
            at: Date(timeIntervalSince1970: 104.25)
        )

        try expectEqual(estimated, snapshot)
    }

    static func testStoppedSnapshotDoesNotAdvance() throws {
        let snapshot = NowPlayingSnapshot(
            song: sampleSong,
            playback: .stopped,
            position: 10,
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let estimated = TimerPositionEstimator.estimate(
            from: snapshot,
            at: Date(timeIntervalSince1970: 104.25)
        )

        try expectEqual(estimated, snapshot)
    }

    static func testNilPositionDoesNotAdvance() throws {
        let snapshot = NowPlayingSnapshot(
            song: sampleSong,
            playback: .playing,
            position: nil,
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let estimated = TimerPositionEstimator.estimate(
            from: snapshot,
            at: Date(timeIntervalSince1970: 104.25)
        )

        try expectEqual(estimated, snapshot)
    }

    static func testEarlierEstimateDateDoesNotReducePosition() throws {
        let snapshot = NowPlayingSnapshot(
            song: sampleSong,
            playback: .playing,
            position: 10,
            capturedAt: Date(timeIntervalSince1970: 100)
        )

        let estimated = TimerPositionEstimator.estimate(
            from: snapshot,
            at: Date(timeIntervalSince1970: 95)
        )

        try expectEqual(estimated.position, 10)
        try expectEqual(estimated.capturedAt, Date(timeIntervalSince1970: 95))
    }

    static func testSnapshotServiceReturnsEstimatedLatestSnapshot() async throws {
        let service = SnapshotNowPlayingService()

        await service.update(
            NowPlayingSnapshot(
                song: sampleSong,
                playback: .playing,
                position: 10,
                capturedAt: Date(timeIntervalSinceNow: -0.05)
            )
        )

        let before = Date()
        let estimated = await service.snapshot()
        let after = Date()

        guard let position = estimated.position else {
            throw TestFailure(message: "Expected estimated position")
        }

        try expectTrue(position >= 10)
        try expectTrue(estimated.capturedAt >= before)
        try expectTrue(estimated.capturedAt <= after)
    }

    static func testExternalNowPlayingPayloadAdvancesElapsedTimeFromTimestamp() throws {
        let snapshot = ExternalNowPlayingPayload(
            title: "一路向北",
            artist: "周杰伦",
            elapsedTime: 20,
            playbackRate: 1,
            timestamp: Date(timeIntervalSince1970: 100)
        ).snapshot(at: Date(timeIntervalSince1970: 103.25))

        try expectEqual(snapshot.song?.id, "external:mediaremote:一路向北:周杰伦")
        try expectEqual(snapshot.song?.title, "一路向北")
        try expectEqual(snapshot.playback, .playing)
        try expectEqual(snapshot.position, 23.25)
        try expectEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 103.25))
    }

    private static let sampleSong = Song(
        id: "1901371647",
        title: "晴天",
        artist: "周杰伦"
    )
}
