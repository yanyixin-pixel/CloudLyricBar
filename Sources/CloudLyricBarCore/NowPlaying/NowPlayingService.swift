import Foundation

public protocol NowPlayingProviding: Sendable {
    func snapshot() async -> NowPlayingSnapshot
}

public enum TimerPositionEstimator {
    public static func estimate(from snapshot: NowPlayingSnapshot, at date: Date = Date()) -> NowPlayingSnapshot {
        guard snapshot.playback == .playing, let position = snapshot.position else {
            return snapshot
        }

        let elapsed = max(0, date.timeIntervalSince(snapshot.capturedAt))

        return NowPlayingSnapshot(
            song: snapshot.song,
            playback: snapshot.playback,
            position: position + elapsed,
            capturedAt: date
        )
    }
}

public actor SnapshotNowPlayingService: NowPlayingProviding {
    private var latestSnapshot: NowPlayingSnapshot

    public init(
        initialSnapshot: NowPlayingSnapshot = NowPlayingSnapshot(
            song: nil,
            playback: .stopped,
            position: nil
        )
    ) {
        self.latestSnapshot = initialSnapshot
    }

    public func update(_ snapshot: NowPlayingSnapshot) {
        latestSnapshot = snapshot
    }

    public func snapshot() async -> NowPlayingSnapshot {
        TimerPositionEstimator.estimate(from: latestSnapshot)
    }
}
