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
    private let permissionCoordinator: PermissionCoordinator?
    private let audioPlayer: (any SongAudioPlaying)?
    private let nowPlayingProvider: (any NowPlayingProviding)?
    private var cachedLyrics: [String: [LyricLine]] = [:]
    private var resolvedExternalSongs: [ExternalSongKey: Song] = [:]
    private var latestNowPlaying: NowPlayingSnapshot?
    private var latestClientRunning = false
    private var applyRevision = 0

    public init(
        apiClient: any NetEaseAPIClient,
        playbackControl: (any PlaybackControlling)? = nil,
        permissionCoordinator: PermissionCoordinator? = nil,
        audioPlayer: (any SongAudioPlaying)? = nil,
        nowPlayingProvider: (any NowPlayingProviding)? = nil
    ) {
        self.apiClient = apiClient
        self.playbackControl = playbackControl
        self.permissionCoordinator = permissionCoordinator
        self.audioPlayer = audioPlayer
        self.nowPlayingProvider = nowPlayingProvider
    }

    public func apply(nowPlaying: NowPlayingSnapshot, isClientRunning: Bool) async {
        applyRevision += 1
        let revision = applyRevision
        latestNowPlaying = nowPlaying
        latestClientRunning = isClientRunning
        playback = nowPlaying.playback

        var displaySong = nowPlaying.song
        currentSong = displaySong
        let cachedSource = displaySong.flatMap(cachedLyricSource)
        let canRenderFromCache = cachedSource.flatMap { cachedLyrics[$0.id] } != nil
        if !canRenderFromCache {
            renderMenuBar(
                playback: nowPlaying.playback,
                lyricText: nil,
                fallbackTitle: displaySong?.title,
                isClientRunning: isClientRunning
            )
        }

        var lines: [LyricLine] = []
        if let song = nowPlaying.song {
            do {
                let lyricSong = try await lyricSource(for: song)
                guard isCurrentApply(revision) else { return }
                displaySong = songWithPreferredArtwork(lyricSong, fallbackArtworkURL: song.artworkURL)
                lines = try await lyrics(for: lyricSong.id)
                guard isCurrentApply(revision) else { return }
                message = nil
            } catch {
                guard isCurrentApply(revision) else { return }
                message = "歌词加载失败"
            }
        }

        currentSong = displaySong
        lyricContext = LyricSyncEngine.context(at: nowPlaying.position ?? 0, in: lines)
        renderMenuBar(
            playback: nowPlaying.playback,
            lyricText: lyricContext.current?.text,
            fallbackTitle: displaySong?.title,
            isClientRunning: isClientRunning
        )
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
            if let audioPlayer {
                let streamURL = try await apiClient.fetchSongStreamURL(songID: song.id)
                try await audioPlayer.play(song: song, streamURL: streamURL)
                await apply(nowPlaying: await audioPlayer.snapshot(), isClientRunning: true)
            } else {
                let position = latestNowPlaying?.position ?? 0
                let playback = latestNowPlaying?.playback ?? .playing
                await apply(
                    nowPlaying: NowPlayingSnapshot(song: song, playback: playback, position: position),
                    isClientRunning: true
                )
            }
            message = nil
        } catch {
            message = "无法让网易云播放这首歌"
        }
    }

    public func refreshEstimatedPlayback(at date: Date = Date()) async {
        if let nowPlayingProvider {
            let snapshot = await nowPlayingProvider.snapshot()
            await apply(nowPlaying: TimerPositionEstimator.estimate(from: snapshot, at: date), isClientRunning: true)
            return
        }

        if let audioPlayer {
            await apply(nowPlaying: await audioPlayer.snapshot(), isClientRunning: true)
            return
        }

        guard let latestNowPlaying else { return }

        let estimated = TimerPositionEstimator.estimate(from: latestNowPlaying, at: date)
        await apply(nowPlaying: estimated, isClientRunning: latestClientRunning)
    }

    public func sendPlaybackCommand(_ command: PlaybackCommand) async {
        do {
            if let audioPlayer {
                try await audioPlayer.send(command)
                await apply(nowPlaying: await audioPlayer.snapshot(), isClientRunning: true)
            } else {
                try await playbackControl?.send(command)
            }
            message = nil
        } catch {
            message = "播放控制失败"
        }
    }

    public func requestPlaybackControlPermission() async {
        await permissionCoordinator?.requestAccessibility()
        message = "请在系统设置中允许辅助功能权限"
    }

    private func lyrics(for songID: String) async throws -> [LyricLine] {
        if let cached = cachedLyrics[songID] {
            return cached
        }

        let lines = try await apiClient.fetchLyrics(songID: songID)
        cachedLyrics[songID] = lines
        return lines
    }

    private func renderMenuBar(
        playback: PlaybackState,
        lyricText: String?,
        fallbackTitle: String?,
        isClientRunning: Bool
    ) {
        let display = MenuBarDisplayState(
            playback: playback,
            lyricText: lyricText,
            fallbackTitle: fallbackTitle,
            isClientRunning: isClientRunning
        )
        if menuBarTitle != display.title {
            menuBarTitle = display.title
        }
    }

    private func isCurrentApply(_ revision: Int) -> Bool {
        revision == applyRevision
    }

    private func cachedLyricSource(for song: Song) -> Song? {
        guard song.id.hasPrefix("external:") else {
            return song
        }

        return resolvedExternalSongs[ExternalSongKey(song: song)]
    }

    private func songWithPreferredArtwork(_ song: Song, fallbackArtworkURL: URL?) -> Song {
        guard let fallbackArtworkURL, song.artworkURL != fallbackArtworkURL else {
            return song
        }

        return Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURL: fallbackArtworkURL
        )
    }

    private func lyricSource(for song: Song) async throws -> Song {
        guard song.id.hasPrefix("external:") else {
            return song
        }

        let key = ExternalSongKey(song: song)
        if let cached = resolvedExternalSongs[key] {
            return cached
        }

        let keyword = [song.title, song.artist]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let match = try await apiClient.searchSongs(keyword: keyword).first ?? song
        resolvedExternalSongs[key] = match
        return match
    }
}

private struct ExternalSongKey: Hashable {
    let title: String
    let artist: String

    init(song: Song) {
        title = song.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        artist = song.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
