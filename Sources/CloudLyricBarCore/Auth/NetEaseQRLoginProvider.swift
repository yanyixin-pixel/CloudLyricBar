import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct NetEaseQRLoginProvider: QRLoginProviding {
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

    public func createQRCode() async throws -> QRCodeLogin {
        let keyRequest = try request(path: "/login/qr/key", queryItems: [
            timestampQueryItem()
        ])
        let keyData = try await transport.data(for: keyRequest)
        let keyResponse = try decoder.decode(QRKeyResponse.self, from: keyData)

        guard keyResponse.code == 200 else {
            throw NetEaseAPIError.badStatus(keyResponse.code)
        }

        let key = keyResponse.data.unikey
        let createRequest = try request(path: "/login/qr/create", queryItems: [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "qrimg", value: "false"),
            timestampQueryItem()
        ])
        let createData = try await transport.data(for: createRequest)
        let createResponse = try decoder.decode(QRCreateResponse.self, from: createData)

        guard createResponse.code == 200 else {
            throw NetEaseAPIError.badStatus(createResponse.code)
        }

        guard let url = URL(string: createResponse.data.qrurl), url.scheme != nil else {
            throw NetEaseAPIError.invalidURL
        }

        return QRCodeLogin(key: key, url: url)
    }

    public func poll(key: String) async throws -> QRLoginPollResult {
        let request = try request(path: "/login/qr/check", queryItems: [
            URLQueryItem(name: "key", value: key),
            timestampQueryItem()
        ])
        let data = try await transport.data(for: request)
        let response = try decoder.decode(QRCheckResponse.self, from: data)

        switch response.code {
        case 800:
            return .expired
        case 801, 802:
            return .waiting
        case 803:
            guard let cookie = response.cookie, let id = response.account?.id else {
                throw NetEaseAPIError.badStatus(response.code)
            }

            return .confirmed(NetEaseSession(userID: String(id), cookie: cookie))
        default:
            throw NetEaseAPIError.badStatus(response.code)
        }
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

    private func timestampQueryItem() -> URLQueryItem {
        let milliseconds = Int(Date().timeIntervalSince1970 * 1000)
        return URLQueryItem(name: "timestamp", value: String(milliseconds))
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

private struct QRKeyResponse: Decodable {
    let code: Int
    let data: DataPayload

    struct DataPayload: Decodable {
        let unikey: String
    }
}

private struct QRCreateResponse: Decodable {
    let code: Int
    let data: DataPayload

    struct DataPayload: Decodable {
        let qrurl: String
    }
}

private struct QRCheckResponse: Decodable {
    let code: Int
    let cookie: String?
    let account: Account?

    struct Account: Decodable {
        let id: Int64
    }
}
