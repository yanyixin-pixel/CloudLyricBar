import Foundation

public protocol NowPlayingProviding: Sendable {
    func snapshot() async -> NowPlayingSnapshot
}

public struct ExternalNowPlayingPayload: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let elapsedTime: TimeInterval?
    public let playbackRate: Double
    public let timestamp: Date?
    public let artworkURL: URL?

    public init(
        title: String,
        artist: String,
        elapsedTime: TimeInterval?,
        playbackRate: Double,
        timestamp: Date?,
        artworkURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.timestamp = timestamp
        self.artworkURL = artworkURL
    }

    public func snapshot(at date: Date = Date()) -> NowPlayingSnapshot {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return NowPlayingSnapshot(song: nil, playback: .stopped, position: nil, capturedAt: date)
        }

        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let playback: PlaybackState = playbackRate > 0.01 ? .playing : .paused
        let position = estimatedPosition(at: date)
        let song = Song(
            id: "external:mediaremote:\(trimmedTitle):\(trimmedArtist)",
            title: trimmedTitle,
            artist: trimmedArtist,
            artworkURL: artworkURL
        )

        return NowPlayingSnapshot(song: song, playback: playback, position: position, capturedAt: date)
    }

    private func estimatedPosition(at date: Date) -> TimeInterval? {
        guard let elapsedTime else {
            return nil
        }

        guard playbackRate > 0.01, let timestamp else {
            return elapsedTime
        }

        return elapsedTime + max(0, date.timeIntervalSince(timestamp)) * playbackRate
    }
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
