import Combine
import Foundation

@MainActor
public final class CloudLyricBarViewModel: ObservableObject {
    @Published public private(set) var menuBarTitle: String = "♪"
    @Published public private(set) var lyricContext = LyricContext(previous: nil, current: nil, next: nil)
    @Published public private(set) var currentSong: Song?
    @Published public private(set) var playback: PlaybackState = .stopped
    @Published public private(set) var playlists: [Playlist] = []
    @Published public private(set) var searchResults: [Song] = []
    @Published public private(set) var message: String?

    private let apiClient: any NetEaseAPIClient
    private let playbackControl: (any PlaybackControlling)?
    private var cachedLyrics: [String: [LyricLine]] = [:]

    public init(apiClient: any NetEaseAPIClient, playbackControl: (any PlaybackControlling)? = nil) {
        self.apiClient = apiClient
        self.playbackControl = playbackControl
    }

    public func apply(nowPlaying: NowPlayingSnapshot, isClientRunning: Bool) async {
        currentSong = nowPlaying.song
        playback = nowPlaying.playback

        var lines: [LyricLine] = []
        if let song = nowPlaying.song {
            do {
                lines = try await lyrics(for: song.id)
                message = nil
            } catch {
                message = "歌词加载失败"
            }
        }

        lyricContext = LyricSyncEngine.context(at: nowPlaying.position ?? 0, in: lines)
        let display = MenuBarDisplayState(
            playback: nowPlaying.playback,
            lyricText: lyricContext.current?.text,
            fallbackTitle: nowPlaying.song?.title,
            isClientRunning: isClientRunning
        )
        menuBarTitle = display.title
    }

    public func loadPlaylists(userID: String) async {
        do {
            playlists = try await apiClient.userPlaylists(userID: userID)
            message = nil
        } catch {
            message = "歌单加载失败"
        }
    }

    public func search(keyword: String) async {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await apiClient.searchSongs(keyword: trimmedKeyword)
            message = nil
        } catch {
            message = "搜索失败"
        }
    }

    public func play(_ song: Song) async {
        do {
            try await playbackControl?.send(.openSong(id: song.id))
            message = nil
        } catch {
            message = "无法让网易云播放这首歌"
        }
    }

    public func sendPlaybackCommand(_ command: PlaybackCommand) async {
        do {
            try await playbackControl?.send(command)
            message = nil
        } catch {
            message = "播放控制失败"
        }
    }

    private func lyrics(for songID: String) async throws -> [LyricLine] {
        if let cached = cachedLyrics[songID] {
            return cached
        }

        let lines = try await apiClient.fetchLyrics(songID: songID)
        cachedLyrics[songID] = lines
        return lines
    }
}
