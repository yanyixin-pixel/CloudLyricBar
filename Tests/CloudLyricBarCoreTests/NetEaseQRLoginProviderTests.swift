import CloudLyricBarCore
import Foundation

let netEaseQRLoginProviderTests: [TestCase] = [
    TestCase(
        name: "NetEaseQRLoginProviderTests.testCreateQRCodeReturnsKeyAndURL",
        run: NetEaseQRLoginProviderTests.testCreateQRCodeReturnsKeyAndURL
    ),
    TestCase(
        name: "NetEaseQRLoginProviderTests.testPollConfirmedReturnsSession",
        run: NetEaseQRLoginProviderTests.testPollConfirmedReturnsSession
    ),
    TestCase(
        name: "NetEaseQRLoginProviderTests.testPollWaitingAndExpiredMappings",
        run: NetEaseQRLoginProviderTests.testPollWaitingAndExpiredMappings
    )
]

enum NetEaseQRLoginProviderTests {
    static func testCreateQRCodeReturnsKeyAndURL() async throws {
        let transport = QueuedHTTPTransport(responses: [
            #"{"code":200,"data":{"unikey":"abc-key"}}"#,
            #"{"code":200,"data":{"qrurl":"https://music.example/login?key=abc-key"}}"#
        ])
        let provider = NetEaseQRLoginProvider(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let login = try await provider.createQRCode()
        let requests = await transport.recordedRequests()

        try expectEqual(login, QRCodeLogin(key: "abc-key", url: try requireURL("https://music.example/login?key=abc-key")))
        try expectEqual(requests.map { $0.url?.path }, ["/login/qr/key", "/login/qr/create"])
        try expectQueryItem(requests.first?.url, name: "timestamp")
        try expectQueryItem(requests.dropFirst().first?.url, name: "key", value: "abc-key")
        try expectQueryItem(requests.dropFirst().first?.url, name: "qrimg", value: "false")
        try expectQueryItem(requests.dropFirst().first?.url, name: "timestamp")
    }

    static func testPollConfirmedReturnsSession() async throws {
        let transport = QueuedHTTPTransport(responses: [
            #"{"code":803,"cookie":"MUSIC_U=abc;","account":{"id":42}}"#
        ])
        let provider = NetEaseQRLoginProvider(
            baseURL: try requireURL("https://music.example"),
            transport: transport
        )

        let result = try await provider.poll(key: "abc-key")
        let requests = await transport.recordedRequests()

        try expectEqual(result, .confirmed(NetEaseSession(userID: "42", cookie: "MUSIC_U=abc;")))
        try expectEqual(requests.first?.url?.path, "/login/qr/check")
        try expectQueryItem(requests.first?.url, name: "key", value: "abc-key")
        try expectQueryItem(requests.first?.url, name: "timestamp")
    }

    static func testPollWaitingAndExpiredMappings() async throws {
        let waitingTransport = QueuedHTTPTransport(responses: [
            #"{"code":801}"#,
            #"{"code":802}"#
        ])
        let waitingProvider = NetEaseQRLoginProvider(
            baseURL: try requireURL("https://music.example"),
            transport: waitingTransport
        )

        try expectEqual(try await waitingProvider.poll(key: "abc-key"), .waiting)
        try expectEqual(try await waitingProvider.poll(key: "abc-key"), .waiting)

        let expiredTransport = QueuedHTTPTransport(responses: [
            #"{"code":800}"#
        ])
        let expiredProvider = NetEaseQRLoginProvider(
            baseURL: try requireURL("https://music.example"),
            transport: expiredTransport
        )

        try expectEqual(try await expiredProvider.poll(key: "abc-key"), .expired)
    }
}

private actor QueuedHTTPTransport: HTTPTransport {
    private var responses: [Data]
    private var requests: [URLRequest] = []

    init(responses: [String]) {
        self.responses = responses.map { Data($0.utf8) }
    }

    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        guard !responses.isEmpty else {
            throw TestFailure(message: "Expected queued response")
        }

        return responses.removeFirst()
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

private func expectQueryItem(_ url: URL?, name: String, value: String? = nil) throws {
    let components = URLComponents(url: try requireValue(url, "Expected request URL"), resolvingAgainstBaseURL: false)
    let item = components?.queryItems?.first { $0.name == name }
    try expectTrue(item != nil, "Expected query item \(name)")

    if let value {
        try expectEqual(item?.value, value)
    }
}

private func requireURL(_ string: String) throws -> URL {
    try requireValue(URL(string: string), "Expected valid URL: \(string)")
}

private func requireValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
        throw TestFailure(message: message)
    }

    return value
}
