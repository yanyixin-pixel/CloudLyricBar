import Foundation

public enum PlaybackState: Sendable, Equatable {
    case playing
    case paused
    case stopped
}

public struct Song: Sendable, Equatable {
    public var id: String?
    public var title: String
    public var artist: String?
    public var album: String?

    public init(
        id: String? = nil,
        title: String,
        artist: String? = nil,
        album: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
    }
}

public struct Playlist: Sendable, Equatable {
    public var id: String?
    public var name: String
    public var songs: [Song]

    public init(
        id: String? = nil,
        name: String,
        songs: [Song] = []
    ) {
        self.id = id
        self.name = name
        self.songs = songs
    }
}

public struct LyricLine: Sendable, Equatable {
    public var startTime: Double
    public var text: String

    public init(startTime: Double, text: String) {
        self.startTime = startTime
        self.text = text
    }
}

public struct LyricContext: Sendable, Equatable {
    public var lines: [LyricLine]
    public var currentLine: LyricLine?

    public init(lines: [LyricLine] = [], currentLine: LyricLine? = nil) {
        self.lines = lines
        self.currentLine = currentLine
    }
}

public struct NowPlayingSnapshot: Sendable, Equatable {
    public var isClientRunning: Bool
    public var playback: PlaybackState
    public var song: Song?
    public var playlist: Playlist?
    public var lyricContext: LyricContext?
    public var elapsedTime: Double?

    public init(
        isClientRunning: Bool,
        playback: PlaybackState,
        song: Song? = nil,
        playlist: Playlist? = nil,
        lyricContext: LyricContext? = nil,
        elapsedTime: Double? = nil
    ) {
        self.isClientRunning = isClientRunning
        self.playback = playback
        self.song = song
        self.playlist = playlist
        self.lyricContext = lyricContext
        self.elapsedTime = elapsedTime
    }
}

public struct MenuBarDisplayState: Sendable, Equatable {
    public var isClientRunning: Bool
    public var playback: PlaybackState
    public var lyricText: String?
    public var fallbackTitle: String?

    public init(
        isClientRunning: Bool,
        playback: PlaybackState,
        lyricText: String? = nil,
        fallbackTitle: String? = nil
    ) {
        self.isClientRunning = isClientRunning
        self.playback = playback
        self.lyricText = lyricText
        self.fallbackTitle = fallbackTitle
    }

    public var title: String {
        guard isClientRunning else {
            return "♪"
        }

        if playback == .playing, let lyric = nonEmpty(lyricText) {
            return "♪ \(lyric)"
        }

        if let fallbackTitle = nonEmpty(fallbackTitle) {
            return "♪ \(fallbackTitle)"
        }

        return "♪"
    }

    public var shouldAnimate: Bool {
        playback == .playing && nonEmpty(lyricText) != nil
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
