import CloudLyricBarCore
import Foundation

let netEaseAuthServiceTests: [TestCase] = [
    TestCase(
        name: "NetEaseAuthServiceTests.testExistingSessionReturnsAuthenticatedState",
        run: NetEaseAuthServiceTests.testExistingSessionReturnsAuthenticatedState
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testQRCodeSuccessPersistsSessionAndAuthenticates",
        run: NetEaseAuthServiceTests.testQRCodeSuccessPersistsSessionAndAuthenticates
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testCreateQRCodeDelegatesToProvider",
        run: NetEaseAuthServiceTests.testCreateQRCodeDelegatesToProvider
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testExpiredQRCodeReturnsFailedState",
        run: NetEaseAuthServiceTests.testExpiredQRCodeReturnsFailedState
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testWaitingQRCodeReturnsWaitingForScan",
        run: NetEaseAuthServiceTests.testWaitingQRCodeReturnsWaitingForScan
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testProviderErrorPropagates",
        run: NetEaseAuthServiceTests.testProviderErrorPropagates
    ),
    TestCase(
        name: "NetEaseAuthServiceTests.testKeychainSessionStoreSaveLoadOverwriteAndClear",
        run: NetEaseAuthServiceTests.testKeychainSessionStoreSaveLoadOverwriteAndClear
    )
]

enum NetEaseAuthServiceTests {
    static func testExistingSessionReturnsAuthenticatedState() async throws {
        let store = InMemorySessionStore(session: NetEaseSession(userID: "42", cookie: "MUSIC_U=abc"))
        let service = NetEaseAuthService(sessionStore: store, qrLoginProvider: StubQRLoginProvider(pollResult: .waiting))

        let state = await service.currentState()

        try expectEqual(state, .authenticated(userID: "42"))
    }

    static func testQRCodeSuccessPersistsSessionAndAuthenticates() async throws {
        let store = InMemorySessionStore()
        let session = NetEaseSession(userID: "42", cookie: "MUSIC_U=abc")
        let service = NetEaseAuthService(sessionStore: store, qrLoginProvider: StubQRLoginProvider(pollResult: .confirmed(session)))

        let state = try await service.pollQRCode(key: "abc-key")
        let savedSession = try await store.load()

        try expectEqual(state, .authenticated(userID: "42"))
        try expectEqual(savedSession, session)
    }

    static func testCreateQRCodeDelegatesToProvider() async throws {
        let login = QRCodeLogin(key: "abc-key", url: URL(string: "https://music.example/login")!)
        let service = NetEaseAuthService(
            sessionStore: InMemorySessionStore(),
            qrLoginProvider: StubQRLoginProvider(login: login, pollResult: .waiting)
        )

        try await expectEqual(service.createQRCode(), login)
    }

    static func testExpiredQRCodeReturnsFailedState() async throws {
        let service = NetEaseAuthService(sessionStore: InMemorySessionStore(), qrLoginProvider: StubQRLoginProvider(pollResult: .expired))

        let state = try await service.pollQRCode(key: "abc-key")

        try expectEqual(state, .failed("二维码已过期"))
    }

    static func testWaitingQRCodeReturnsWaitingForScan() async throws {
        let service = NetEaseAuthService(sessionStore: InMemorySessionStore(), qrLoginProvider: StubQRLoginProvider(pollResult: .waiting))

        let state = try await service.pollQRCode(key: "abc-key")

        try expectEqual(state, .waitingForScan)
    }

    static func testProviderErrorPropagates() async throws {
        let service = NetEaseAuthService(sessionStore: InMemorySessionStore(), qrLoginProvider: ThrowingQRLoginProvider())

        do {
            _ = try await service.pollQRCode(key: "abc-key")
            throw TestFailure(message: "Expected provider error to propagate")
        } catch TestAuthError.providerFailure {
        }
    }

    static func testKeychainSessionStoreSaveLoadOverwriteAndClear() async throws {
        let store = KeychainSessionStore(service: "CloudLyricBar.NetEaseSession.Tests.\(UUID().uuidString)")
        try? await store.clear()

        do {
            try expectEqual(try await store.load(), nil)

            let firstSession = NetEaseSession(userID: "42", cookie: "MUSIC_U=abc")
            try await store.save(firstSession)
            try expectEqual(try await store.load(), firstSession)

            let secondSession = NetEaseSession(userID: "43", cookie: "MUSIC_U=def")
            try await store.save(secondSession)
            try expectEqual(try await store.load(), secondSession)

            try await store.clear()
            try expectEqual(try await store.load(), nil)
        } catch {
            try? await store.clear()
            throw error
        }
    }
}

private struct StubQRLoginProvider: QRLoginProviding {
    var login = QRCodeLogin(key: "abc-key", url: URL(string: "https://music.example/login")!)
    let pollResult: QRLoginPollResult

    func createQRCode() async throws -> QRCodeLogin {
        login
    }

    func poll(key: String) async throws -> QRLoginPollResult {
        pollResult
    }
}

private struct ThrowingQRLoginProvider: QRLoginProviding {
    func createQRCode() async throws -> QRCodeLogin {
        throw TestAuthError.providerFailure
    }

    func poll(key: String) async throws -> QRLoginPollResult {
        throw TestAuthError.providerFailure
    }
}

private enum TestAuthError: Error {
    case providerFailure
}
