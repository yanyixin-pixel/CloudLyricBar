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
