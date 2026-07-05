import CloudLyricBarCore
import Foundation

let netEaseDTOTests: [TestCase] = [
    TestCase(
        name: "NetEaseDTOTests.testDecodesPlaylistResponseAndMapsDomainPlaylists",
        run: NetEaseDTOTests.testDecodesPlaylistResponseAndMapsDomainPlaylists
    ),
    TestCase(
        name: "NetEaseDTOTests.testDecodesSearchResponseAndMapsDomainSong",
        run: NetEaseDTOTests.testDecodesSearchResponseAndMapsDomainSong
    ),
    TestCase(
        name: "NetEaseDTOTests.testDecodesLyricResponseAndParsesLines",
        run: NetEaseDTOTests.testDecodesLyricResponseAndParsesLines
    ),
    TestCase(
        name: "NetEaseDTOTests.testDecodesSongURLResponseAndReturnsFirstPlayableURL",
        run: NetEaseDTOTests.testDecodesSongURLResponseAndReturnsFirstPlayableURL
    )
]

enum NetEaseDTOTests {
    static func testDecodesPlaylistResponseAndMapsDomainPlaylists() throws {
        let response = try decodeFixture("playlist", as: NetEasePlaylistResponse.self)

        try expectEqual(response.code, 200)
        try expectEqual(
            response.playlists.map(\.domain),
            [
                Playlist(id: "123", name: "我喜欢的音乐", trackCount: 88),
                Playlist(id: "456", name: "夜晚播放", trackCount: 24)
            ]
        )
    }

    static func testDecodesSearchResponseAndMapsDomainSong() throws {
        let response = try decodeFixture("search", as: NetEaseSearchResponse.self)

        try expectEqual(response.code, 200)
        try expectEqual(response.songs.count, 1)
        try expectEqual(
            response.songs.first?.domain,
            Song(
                id: "1901371647",
                title: "一路向北",
                artist: "周杰伦",
                album: "十一月的萧邦",
                artworkURL: URL(string: "https://p1.music.126.net/artwork.jpg")
            )
        )
    }

    static func testDecodesLyricResponseAndParsesLines() throws {
        let response = try decodeFixture("lyric", as: NetEaseLyricResponse.self)

        try expectEqual(response.code, 200)
        try expectEqual(
            response.lines,
            [
                LyricLine(startTime: 1, text: "第一句歌词"),
                LyricLine(startTime: 3.5, text: "第二句歌词")
            ]
        )
    }

    static func testDecodesSongURLResponseAndReturnsFirstPlayableURL() throws {
        let response = try decodeFixture("song-url", as: NetEaseSongURLResponse.self)

        try expectEqual(response.code, 200)
        try expectEqual(response.playableURL, URL(string: "https://music.example/song.mp3"))
    }

    private static func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let data = try fixtureData(named: name)
        return try JSONDecoder().decode(T.self, from: data)
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
