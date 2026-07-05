import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> Data
}

public enum NetEaseAPIError: Error, Equatable {
    case invalidURL
    case badStatus(Int)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NetEaseAPIError.badStatus(httpResponse.statusCode)
        }

        return data
    }
}

public protocol NetEaseAPIClient: Sendable {
    func userPlaylists(userID: String) async throws -> [Playlist]
    func searchSongs(keyword: String) async throws -> [Song]
    func fetchLyrics(songID: String) async throws -> [LyricLine]
}

public struct URLSessionNetEaseAPIClient: NetEaseAPIClient, @unchecked Sendable {
    public let baseURL: URL
    private let transport: any HTTPTransport
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.decoder = decoder
    }

    public func userPlaylists(userID: String) async throws -> [Playlist] {
        let request = try request(path: "/user/playlist", queryItems: [
            URLQueryItem(name: "uid", value: userID)
        ])
        let data = try await transport.data(for: request)
        let response = try decoder.decode(NetEasePlaylistResponse.self, from: data)
        return response.playlists.map(\.domain)
    }

    public func searchSongs(keyword: String) async throws -> [Song] {
        let request = try request(path: "/search", queryItems: [
            URLQueryItem(name: "keywords", value: keyword),
            URLQueryItem(name: "type", value: "1")
        ])
        let data = try await transport.data(for: request)
        let response = try decoder.decode(NetEaseSearchResponse.self, from: data)
        return response.songs.map(\.domain)
    }

    public func fetchLyrics(songID: String) async throws -> [LyricLine] {
        let request = try request(path: "/lyric", queryItems: [
            URLQueryItem(name: "id", value: songID)
        ])
        let data = try await transport.data(for: request)
        let response = try decoder.decode(NetEaseLyricResponse.self, from: data)
        return response.lines
    }

    private func request(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetEaseAPIError.invalidURL
        }

        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetEaseAPIError.invalidURL
        }

        return URLRequest(url: url)
    }
}
