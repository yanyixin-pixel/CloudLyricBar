import CloudLyricBarCore
import Foundation

let cloudLyricBarViewModelTests: [TestCase] = [
    TestCase(
        name: "CloudLyricBarViewModelTests.testRefreshLyricsUpdatesMenuBarTitle",
        run: CloudLyricBarViewModelTests.testRefreshLyricsUpdatesMenuBarTitle
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testSearchEmptyKeywordClearsResultsWithoutCallingAPI",
        run: CloudLyricBarViewModelTests.testSearchEmptyKeywordClearsResultsWithoutCallingAPI
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testLyricsAreCachedPerSong",
        run: CloudLyricBarViewModelTests.testLyricsAreCachedPerSong
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testLoadPlaylistsUpdatesState",
        run: CloudLyricBarViewModelTests.testLoadPlaylistsUpdatesState
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback",
        run: CloudLyricBarViewModelTests.testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testSelectingSongUpdatesCurrentSongAndLyrics",
        run: CloudLyricBarViewModelTests.testSelectingSongUpdatesCurrentSongAndLyrics
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testSelectingSongStartsAudioPlayerAndSyncsLyricsFromPlayerPosition",
        run: CloudLyricBarViewModelTests.testSelectingSongStartsAudioPlayerAndSyncsLyricsFromPlayerPosition
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics",
        run: CloudLyricBarViewModelTests.testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testExternalNowPlayingShowsTitleBeforeLyricLookupFinishes",
        run: CloudLyricBarViewModelTests.testExternalNowPlayingShowsTitleBeforeLyricLookupFinishes
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testRefreshEstimatedPlaybackAdvancesLyrics",
        run: CloudLyricBarViewModelTests.testRefreshEstimatedPlaybackAdvancesLyrics
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testRefreshUsesNowPlayingProviderWhenAvailable",
        run: CloudLyricBarViewModelTests.testRefreshUsesNowPlayingProviderWhenAvailable
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testPlaybackCommandFailureShowsMessage",
        run: CloudLyricBarViewModelTests.testPlaybackCommandFailureShowsMessage
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testRequestPlaybackControlPermissionPromptsAccessibility",
        run: CloudLyricBarViewModelTests.testRequestPlaybackControlPermissionPromptsAccessibility
    )
]

enum CloudLyricBarViewModelTests {
    static func testRefreshLyricsUpdatesMenuBarTitle() async throws {
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "第一句"),
            LyricLine(startTime: 10, text: "第二句")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api)
        let nowPlaying = NowPlayingSnapshot(
            song: Song(id: "1", title: "测试歌", artist: "测试歌手"),
            playback: .playing,
            position: 12
        )

        await model.apply(nowPlaying: nowPlaying, isClientRunning: true)

        let title = await model.menuBarTitle
        let context = await model.lyricContext
        try expectEqual(title, "♪ 第二句")
        try expectEqual(context.current?.text, "第二句")
    }

    static func testSearchEmptyKeywordClearsResultsWithoutCallingAPI() async throws {
        let api = FakeNetEaseAPIClient(searchResults: [
            Song(id: "2", title: "旧结果", artist: "旧歌手")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api)

        await model.search(keyword: "一路向北")
        try await expectEqual(model.searchResults.count, 1)

        await model.search(keyword: "   ")

        try await expectEqual(model.searchResults, [Song]())
        try await expectEqual(api.searchCallCount, 1)
    }

    static func testLyricsAreCachedPerSong() async throws {
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "第一句")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api)
        let song = Song(id: "cached-song", title: "缓存歌", artist: "测试歌手")

        await model.apply(
            nowPlaying: NowPlayingSnapshot(song: song, playback: .playing, position: 0),
            isClientRunning: true
        )
        await model.apply(
            nowPlaying: NowPlayingSnapshot(song: song, playback: .playing, position: 0),
            isClientRunning: true
        )

        try await expectEqual(api.fetchLyricsCallCount, 1)
    }

    static func testLoadPlaylistsUpdatesState() async throws {
        let api = FakeNetEaseAPIClient(playlists: [
            Playlist(id: "123", name: "我喜欢的音乐", trackCount: 88)
        ])
        let model = await CloudLyricBarViewModel(apiClient: api)

        await model.loadPlaylists(userID: "42")

        try await expectEqual(model.playlists, [
            Playlist(id: "123", name: "我喜欢的音乐", trackCount: 88)
        ])
    }

    static func testSelectingSongUsesItAsLyricOverrideWithoutStartingPlayback() async throws {
        let playback = RecordingPlaybackControl()
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "开头一句"),
            LyricLine(startTime: 8, text: "手动校正这一句")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api, playbackControl: playback)
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")

        await model.apply(
            nowPlaying: NowPlayingSnapshot(
                song: Song(id: "external:mediaremote:一路向北:周杰伦", title: "一路向北", artist: "周杰伦"),
                playback: .playing,
                position: 8
            ),
            isClientRunning: true
        )
        await api.clearRecordedCalls()
        await model.play(song)

        try await expectEqual(playback.commands, [])
        try await expectEqual(api.fetchedLyricSongIDs(), ["1901371647"])
        try await expectEqual(model.currentSong, song)
        try await expectEqual(model.lyricContext.current?.text, "手动校正这一句")
        try await expectEqual(model.message, nil)
    }

    static func testSelectingSongUpdatesCurrentSongAndLyrics() async throws {
        let playback = RecordingPlaybackControl()
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "开头一句"),
            LyricLine(startTime: 8, text: "下一句")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api, playbackControl: playback)
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")

        await model.play(song)

        try await expectEqual(model.currentSong, song)
        try await expectEqual(model.playback, .playing)
        try await expectEqual(model.menuBarTitle, "♪ 开头一句")
        try await expectEqual(model.lyricContext.current?.text, "开头一句")
    }

    static func testSelectingSongStartsAudioPlayerAndSyncsLyricsFromPlayerPosition() async throws {
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")
        let streamURL = URL(string: "https://music.example/song.mp3")!
        let player = RecordingSongAudioPlayer(
            snapshot: NowPlayingSnapshot(song: song, playback: .playing, position: 9)
        )
        let api = FakeNetEaseAPIClient(
            lines: [
                LyricLine(startTime: 0, text: "开头一句"),
                LyricLine(startTime: 8, text: "真实进度这一句")
            ],
            streamURL: streamURL
        )
        let model = await CloudLyricBarViewModel(apiClient: api, audioPlayer: player)

        await model.play(song)
        await model.refreshEstimatedPlayback(at: Date(timeIntervalSince1970: 100))

        try await expectEqual(api.fetchedStreamURLSongIDs(), ["1901371647"])
        try await expectEqual(player.playRequests(), [SongAudioPlayRequest(song: song, streamURL: streamURL)])
        try await expectEqual(model.lyricContext.current?.text, "真实进度这一句")
        try await expectEqual(model.menuBarTitle, "♪ 真实进度这一句")
    }

    static func testExternalNowPlayingSongSearchesNetEaseAndUsesResolvedLyrics() async throws {
        let externalSong = Song(id: "external:netease", title: "一路向北", artist: "周杰伦")
        let resolvedSong = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")
        let api = FakeNetEaseAPIClient(
            searchResults: [resolvedSong],
            lines: [
                LyricLine(startTime: 0, text: "开头一句"),
                LyricLine(startTime: 8, text: "匹配后的歌词")
            ]
        )
        let model = await CloudLyricBarViewModel(apiClient: api)

        await model.apply(
            nowPlaying: NowPlayingSnapshot(song: externalSong, playback: .playing, position: 8),
            isClientRunning: true
        )

        try await expectEqual(api.searchKeywords(), ["一路向北 周杰伦"])
        try await expectEqual(api.fetchedLyricSongIDs(), ["1901371647"])
        try await expectEqual(model.currentSong, resolvedSong)
        try await expectEqual(model.lyricContext.current?.text, "匹配后的歌词")
        try await expectEqual(model.menuBarTitle, "♪ 匹配后的歌词")
    }

    static func testExternalNowPlayingShowsTitleBeforeLyricLookupFinishes() async throws {
        let externalSong = Song(id: "external:mediaremote:一路向北:周杰伦", title: "一路向北", artist: "周杰伦")
        let api = BlockingNetEaseAPIClient()
        let model = await CloudLyricBarViewModel(apiClient: api)

        let task = Task {
            await model.apply(
                nowPlaying: NowPlayingSnapshot(song: externalSong, playback: .playing, position: 8),
                isClientRunning: true
            )
        }

        try await api.waitUntilSearchStarted()
        try await expectEqual(model.menuBarTitle, "♪ 一路向北")

        await api.releaseSearch()
        await task.value
    }

    static func testRefreshEstimatedPlaybackAdvancesLyrics() async throws {
        let api = FakeNetEaseAPIClient(lines: [
            LyricLine(startTime: 0, text: "开头一句"),
            LyricLine(startTime: 8, text: "下一句")
        ])
        let model = await CloudLyricBarViewModel(apiClient: api)
        let start = Date(timeIntervalSince1970: 100)
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")

        await model.apply(
            nowPlaying: NowPlayingSnapshot(song: song, playback: .playing, position: 0, capturedAt: start),
            isClientRunning: true
        )
        await model.refreshEstimatedPlayback(at: Date(timeIntervalSince1970: 109))

        try await expectEqual(model.menuBarTitle, "♪ 下一句")
        try await expectEqual(model.lyricContext.current?.text, "下一句")
    }

    static func testRefreshUsesNowPlayingProviderWhenAvailable() async throws {
        let externalSong = Song(id: "external:mediaremote:一路向北:周杰伦", title: "一路向北", artist: "周杰伦")
        let resolvedSong = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")
        let api = FakeNetEaseAPIClient(
            searchResults: [resolvedSong],
            lines: [
                LyricLine(startTime: 0, text: "开头一句"),
                LyricLine(startTime: 8, text: "系统进度这一句")
            ]
        )
        let provider = RecordingNowPlayingProvider(
            snapshot: NowPlayingSnapshot(song: externalSong, playback: .playing, position: 8)
        )
        let model = await CloudLyricBarViewModel(apiClient: api, nowPlayingProvider: provider)

        await model.refreshEstimatedPlayback()

        try await expectEqual(provider.snapshotCallCount(), 1)
        try await expectEqual(api.searchKeywords(), ["一路向北 周杰伦"])
        try await expectEqual(model.currentSong, resolvedSong)
        try await expectEqual(model.lyricContext.current?.text, "系统进度这一句")
        try await expectEqual(model.menuBarTitle, "♪ 系统进度这一句")
    }

    static func testPlaybackCommandFailureShowsMessage() async throws {
        let playback = RecordingPlaybackControl(error: PlaybackControlError.noAvailableStrategy)
        let model = await CloudLyricBarViewModel(apiClient: FakeNetEaseAPIClient(), playbackControl: playback)

        await model.sendPlaybackCommand(.next)

        try await expectEqual(playback.commands, [.next])
        try await expectEqual(model.message, "播放控制失败")
    }

    static func testRequestPlaybackControlPermissionPromptsAccessibility() async throws {
        let probe = RecordingAccessibilityPermissionProbe(isTrusted: false)
        let coordinator = PermissionCoordinator(accessibilityProbe: probe)
        let model = await CloudLyricBarViewModel(
            apiClient: FakeNetEaseAPIClient(),
            permissionCoordinator: coordinator
        )

        await model.requestPlaybackControlPermission()

        try await expectEqual(probe.requestCount(), 1)
        try await expectEqual(model.message, "请在系统设置中允许辅助功能权限")
    }
}

private actor FakeNetEaseAPIClient: NetEaseAPIClient {
    private let playlistsValue: [Playlist]
    private let searchResultsValue: [Song]
    private let linesValue: [LyricLine]
    private let streamURLValue: URL
    private(set) var searchCallCount = 0
    private(set) var fetchLyricsCallCount = 0
    private var searchedKeywords: [String] = []
    private var lyricSongIDs: [String] = []
    private var streamURLSongIDs: [String] = []

    init(
        playlists: [Playlist] = [],
        searchResults: [Song] = [],
        lines: [LyricLine] = [],
        streamURL: URL = URL(string: "https://music.example/default.mp3")!
    ) {
        self.playlistsValue = playlists
        self.searchResultsValue = searchResults
        self.linesValue = lines
        self.streamURLValue = streamURL
    }

    func userPlaylists(userID: String) async throws -> [Playlist] {
        playlistsValue
    }

    func searchSongs(keyword: String) async throws -> [Song] {
        searchCallCount += 1
        searchedKeywords.append(keyword)
        return searchResultsValue
    }

    func fetchLyrics(songID: String) async throws -> [LyricLine] {
        fetchLyricsCallCount += 1
        lyricSongIDs.append(songID)
        return linesValue
    }

    func fetchSongStreamURL(songID: String) async throws -> URL {
        streamURLSongIDs.append(songID)
        return streamURLValue
    }

    func fetchedStreamURLSongIDs() -> [String] {
        streamURLSongIDs
    }

    func searchKeywords() -> [String] {
        searchedKeywords
    }

    func fetchedLyricSongIDs() -> [String] {
        lyricSongIDs
    }

    func clearRecordedCalls() {
        searchedKeywords = []
        lyricSongIDs = []
        streamURLSongIDs = []
        searchCallCount = 0
        fetchLyricsCallCount = 0
    }
}

private actor RecordingPlaybackControl: PlaybackControlling {
    private(set) var commands: [PlaybackCommand] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func send(_ command: PlaybackCommand) async throws {
        commands.append(command)
        if let error {
            throw error
        }
    }
}

private actor BlockingNetEaseAPIClient: NetEaseAPIClient {
    private var searchStartedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var didStartSearch = false

    func userPlaylists(userID: String) async throws -> [Playlist] {
        []
    }

    func searchSongs(keyword: String) async throws -> [Song] {
        didStartSearch = true
        searchStartedContinuation?.resume()
        searchStartedContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return [Song(id: "1901371647", title: "一路向北", artist: "周杰伦")]
    }

    func fetchLyrics(songID: String) async throws -> [LyricLine] {
        [LyricLine(startTime: 0, text: "开头一句")]
    }

    func fetchSongStreamURL(songID: String) async throws -> URL {
        URL(string: "https://music.example/default.mp3")!
    }

    func waitUntilSearchStarted() async throws {
        if didStartSearch {
            return
        }

        await withCheckedContinuation { continuation in
            searchStartedContinuation = continuation
        }
    }

    func releaseSearch() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private struct SongAudioPlayRequest: Equatable {
    let song: Song
    let streamURL: URL
}

private actor RecordingSongAudioPlayer: SongAudioPlaying {
    private var requests: [SongAudioPlayRequest] = []
    private var latestSnapshot: NowPlayingSnapshot

    init(snapshot: NowPlayingSnapshot) {
        latestSnapshot = snapshot
    }

    func play(song: Song, streamURL: URL) async throws {
        requests.append(SongAudioPlayRequest(song: song, streamURL: streamURL))
    }

    func send(_ command: PlaybackCommand) async throws {}

    func snapshot() async -> NowPlayingSnapshot {
        latestSnapshot
    }

    func playRequests() -> [SongAudioPlayRequest] {
        requests
    }
}

private actor RecordingNowPlayingProvider: NowPlayingProviding {
    private let snapshotValue: NowPlayingSnapshot
    private var calls = 0

    init(snapshot: NowPlayingSnapshot) {
        snapshotValue = snapshot
    }

    func snapshot() async -> NowPlayingSnapshot {
        calls += 1
        return snapshotValue
    }

    func snapshotCallCount() -> Int {
        calls
    }
}

private actor RecordingAccessibilityPermissionProbe: AccessibilityPermissionProbing {
    private let trusted: Bool
    private var requests = 0

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    func isTrusted() async -> Bool {
        trusted
    }

    func requestTrustPrompt() async {
        requests += 1
    }

    func requestCount() -> Int {
        requests
    }
}
