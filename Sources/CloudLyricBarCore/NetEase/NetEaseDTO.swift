import Foundation

public struct NetEasePlaylistResponse: Decodable, Sendable {
    public let code: Int
    public let playlists: [NetEasePlaylist]

    private enum CodingKeys: String, CodingKey {
        case code
        case playlists = "playlist"
    }
}

public struct NetEasePlaylist: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let trackCount: Int

    public var domain: Playlist {
        Playlist(id: String(id), name: name, trackCount: trackCount)
    }
}

public struct NetEaseSearchResponse: Decodable, Sendable {
    public let code: Int
    public let result: Result

    public var songs: [NetEaseSong] {
        result.songs
    }

    public struct Result: Decodable, Sendable {
        public let songs: [NetEaseSong]
    }
}

public struct NetEaseSong: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let artists: [Artist]
    public let album: Album

    public var domain: Song {
        Song(
            id: String(id),
            title: name,
            artist: artists.map(\.name).joined(separator: ", "),
            album: album.name,
            artworkURL: album.artworkURL
        )
    }

    public struct Artist: Decodable, Sendable {
        public let name: String
    }

    public struct Album: Decodable, Sendable {
        public let name: String
        public let picUrl: String?

        public var artworkURL: URL? {
            picUrl.flatMap(URL.init(string:))
        }
    }
}

public struct NetEaseLyricResponse: Decodable, Sendable {
    public let code: Int
    public let lrc: LRC?

    public var lines: [LyricLine] {
        LyricParser.parse(lrc?.lyric ?? "")
    }

    public struct LRC: Decodable, Sendable {
        public let lyric: String
    }
}

public struct NetEaseSongURLResponse: Decodable, Sendable {
    public let code: Int
    public let data: [SongURL]

    public var playableURL: URL? {
        data.compactMap(\.url).first
    }

    public struct SongURL: Decodable, Sendable {
        public let id: Int
        public let url: URL?
    }
}
