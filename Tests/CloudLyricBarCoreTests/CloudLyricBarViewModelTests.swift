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
        name: "CloudLyricBarViewModelTests.testSelectingSongSendsOpenSongCommand",
        run: CloudLyricBarViewModelTests.testSelectingSongSendsOpenSongCommand
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testSelectingSongUpdatesCurrentSongAndLyrics",
        run: CloudLyricBarViewModelTests.testSelectingSongUpdatesCurrentSongAndLyrics
    ),
    TestCase(
        name: "CloudLyricBarViewModelTests.testRefreshEstimatedPlaybackAdvancesLyrics",
        run: CloudLyricBarViewModelTests.testRefreshEstimatedPlaybackAdvancesLyrics
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

    static func testSelectingSongSendsOpenSongCommand() async throws {
        let playback = RecordingPlaybackControl()
        let model = await CloudLyricBarViewModel(apiClient: FakeNetEaseAPIClient(), playbackControl: playback)
        let song = Song(id: "1901371647", title: "一路向北", artist: "周杰伦")

        await model.play(song)

        try await expectEqual(playback.commands, [.openSong(id: "1901371647")])
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
    private(set) var searchCallCount = 0
    private(set) var fetchLyricsCallCount = 0

    init(
        playlists: [Playlist] = [],
        searchResults: [Song] = [],
        lines: [LyricLine] = []
    ) {
        self.playlistsValue = playlists
        self.searchResultsValue = searchResults
        self.linesValue = lines
    }

    func userPlaylists(userID: String) async throws -> [Playlist] {
        playlistsValue
    }

    func searchSongs(keyword: String) async throws -> [Song] {
        searchCallCount += 1
        return searchResultsValue
    }

    func fetchLyrics(songID: String) async throws -> [LyricLine] {
        fetchLyricsCallCount += 1
        return linesValue
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
