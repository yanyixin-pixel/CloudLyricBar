import CloudLyricBarCore
import Foundation

let netEaseAPIClientTests: [TestCase] = [
    TestCase(
        name: "NetEaseAPIClientTests.testSearchBuildsExpectedRequestAndDecodesSongs",
        run: NetEaseAPIClientTests.testSearchBuildsExpectedRequestAndDecodesSongs
    ),
    TestCase(
        name: "NetEaseAPIClientTests.testSearchPreservesBaseURLPathPrefix",
        run: NetEaseAPIClientTests.testSearchPreservesBaseURLPathPrefix
    ),
    TestCase(
        name: "NetEaseAPIClientTests.testFetchLyricsDecodesLines",
        run: NetEaseAPIClientTests.testFetchLyricsDecodesLines
    ),
    TestCase(
        name: "NetEaseAPIClientTests.testFetchSongStreamURLBuildsExpectedRequestAndDecodesURL",
        run: NetEaseAPIClientTests.testFetchSongStreamURLBuildsExpectedRequestAndDecodesURL
    ),
    TestCase(
        name: "NetEaseAPIClientTests.testUserPlaylistsBuildsExpectedRequestAndDecodesPlaylists",
        run: NetEaseAPIClientTests.testUserPlaylistsBuildsExpectedRequestAndDecodesPlaylists
    )
]

enum NetEaseAPIClientTests {
    static func testSearchBuildsExpectedRequestAndDecodesSongs() async throws {
        let transport = FakeHTTPTransport(data: try fixtureData(named: "search"))
        let client = URLSessionNetEaseAPIClient(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let songs = try await client.searchSongs(keyword: "一路向北")
        let request = try await transport.requireRequest()

        try expectEqual(request.url?.path, "/search")
        try expectQueryItem(request.url, name: "keywords", value: "一路向北")
        try expectQueryItem(request.url, name: "type", value: "1")
        try expectEqual(songs.first?.title, "一路向北")
    }

    static func testSearchPreservesBaseURLPathPrefix() async throws {
        let transport = FakeHTTPTransport(data: try fixtureData(named: "search"))
        let client = URLSessionNetEaseAPIClient(
            baseURL: try requireURL("https://music.example/api"),
            transport: transport
        )

        _ = try await client.searchSongs(keyword: "一路向北")
        let request = try await transport.requireRequest()

        try expectEqual(request.url?.path, "/api/search")
        try expectQueryItem(request.url, name: "keywords", value: "一路向北")
        try expectQueryItem(request.url, name: "type", value: "1")
    }

    static func testFetchLyricsDecodesLines() async throws {
        let transport = FakeHTTPTransport(data: try fixtureData(named: "lyric"))
        let client = URLSessionNetEaseAPIClient(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let lines = try await client.fetchLyrics(songID: "1901371647")
        let request = try await transport.requireRequest()

        try expectEqual(request.url?.path, "/lyric")
        try expectQueryItem(request.url, name: "id", value: "1901371647")
        try expectEqual(lines.map(\.text), ["第一句歌词", "第二句歌词"])
    }

    static func testFetchSongStreamURLBuildsExpectedRequestAndDecodesURL() async throws {
        let transport = FakeHTTPTransport(data: try fixtureData(named: "song-url"))
        let client = URLSessionNetEaseAPIClient(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let url = try await client.fetchSongStreamURL(songID: "1901371647")
        let request = try await transport.requireRequest()

        try expectEqual(request.url?.path, "/song/url/v1")
        try expectQueryItem(request.url, name: "id", value: "1901371647")
        try expectQueryItem(request.url, name: "level", value: "standard")
        try expectEqual(url, URL(string: "https://music.example/song.mp3"))
    }

    static func testUserPlaylistsBuildsExpectedRequestAndDecodesPlaylists() async throws {
        let transport = FakeHTTPTransport(data: try fixtureData(named: "playlist"))
        let client = URLSessionNetEaseAPIClient(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let playlists = try await client.userPlaylists(userID: "42")
        let request = try await transport.requireRequest()

        try expectEqual(request.url?.path, "/user/playlist")
        try expectQueryItem(request.url, name: "uid", value: "42")
        try expectEqual(playlists.first?.name, "我喜欢的音乐")
    }

    private static func expectQueryItem(_ url: URL?, name: String, value: String) throws {
        let components = URLComponents(url: try requireValue(url, "Expected request URL"), resolvingAgainstBaseURL: false)
        let item = components?.queryItems?.first { $0.name == name }
        try expectEqual(item?.value, value)
    }

    private static func requireURL(_ string: String) throws -> URL {
        try requireValue(URL(string: string), "Expected valid URL: \(string)")
    }

    private static func fixtureData(named name: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")

        return try Data(contentsOf: fixtureURL)
    }
}

private actor FakeHTTPTransport: HTTPTransport {
    private let data: Data
    private var requests: [URLRequest] = []

    init(data: Data) {
        self.data = data
    }

    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        return data
    }

    func requireRequest() throws -> URLRequest {
        try requireValue(requests.first, "Expected request to be recorded")
    }
}

private func requireValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
        throw TestFailure(message: message)
    }

    return value
}
