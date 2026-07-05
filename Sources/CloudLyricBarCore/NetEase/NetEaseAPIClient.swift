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
    case playableURLMissing
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
    func fetchSongStreamURL(songID: String) async throws -> URL
}

public struct URLSessionNetEaseAPIClient: NetEaseAPIClient {
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

    public func fetchSongStreamURL(songID: String) async throws -> URL {
        let request = try request(path: "/song/url/v1", queryItems: [
            URLQueryItem(name: "id", value: songID),
            URLQueryItem(name: "level", value: "standard")
        ])
        let data = try await transport.data(for: request)
        let response = try decoder.decode(NetEaseSongURLResponse.self, from: data)

        guard let url = response.playableURL else {
            throw NetEaseAPIError.playableURLMissing
        }

        return url
    }

    private func request(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetEaseAPIError.invalidURL
        }

        components.path = joinedPath(basePath: components.path, endpointPath: path)
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetEaseAPIError.invalidURL
        }

        return URLRequest(url: url)
    }

    private func joinedPath(basePath: String, endpointPath: String) -> String {
        let trimmedBasePath = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedEndpointPath = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmedBasePath.isEmpty {
            return "/" + trimmedEndpointPath
        }

        if trimmedEndpointPath.isEmpty {
            return "/" + trimmedBasePath
        }

        return "/" + trimmedBasePath + "/" + trimmedEndpointPath
    }
}
