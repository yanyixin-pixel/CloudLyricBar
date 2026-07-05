import Foundation

public enum PlaybackState: Equatable, Sendable {
    case playing
    case paused
    case stopped
}

public struct Song: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkURL: URL?

    public init(id: String, title: String, artist: String, album: String? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
    }
}

public struct Playlist: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let trackCount: Int

    public init(id: String, name: String, trackCount: Int) {
        self.id = id
        self.name = name
        self.trackCount = trackCount
    }
}

public struct LyricLine: Equatable, Identifiable, Sendable {
    public var id: TimeInterval { startTime }
    public let startTime: TimeInterval
    public let text: String

    public init(startTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.text = text
    }
}

public struct LyricContext: Equatable, Sendable {
    public let previous: LyricLine?
    public let current: LyricLine?
    public let next: LyricLine?

    public init(previous: LyricLine?, current: LyricLine?, next: LyricLine?) {
        self.previous = previous
        self.current = current
        self.next = next
    }
}

public struct NowPlayingSnapshot: Equatable, Sendable {
    public let song: Song?
    public let playback: PlaybackState
    public let position: TimeInterval?
    public let capturedAt: Date

    public init(song: Song?, playback: PlaybackState, position: TimeInterval?, capturedAt: Date = Date()) {
        self.song = song
        self.playback = playback
        self.position = position
        self.capturedAt = capturedAt
    }
}

public struct MenuBarDisplayState: Equatable, Sendable {
    public let playback: PlaybackState
    public let lyricText: String?
    public let fallbackTitle: String?
    public let isClientRunning: Bool

    public init(playback: PlaybackState, lyricText: String?, fallbackTitle: String?, isClientRunning: Bool) {
        self.playback = playback
        self.lyricText = lyricText
        self.fallbackTitle = fallbackTitle
        self.isClientRunning = isClientRunning
    }

    public var title: String {
        guard isClientRunning else { return "♪" }

        if playback == .playing, let lyricText, !lyricText.isEmpty {
            return "♪ \(lyricText)"
        }

        if let fallbackTitle, !fallbackTitle.isEmpty {
            return "♪ \(fallbackTitle)"
        }

        return "♪"
    }

    public var shouldAnimate: Bool {
        isClientRunning && playback == .playing && lyricText != nil
    }
}
