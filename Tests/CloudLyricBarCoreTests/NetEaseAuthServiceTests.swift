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
        name: "NetEaseAuthServiceTests.testExpiredQRCodeReturnsFailedState",
        run: NetEaseAuthServiceTests.testExpiredQRCodeReturnsFailedState
    )
]

enum NetEaseAuthServiceTests {
    static func testExistingSessionReturnsAuthenticatedState() async throws {
        let store = InMemorySessionStore(session: NetEaseSession(userID: "42", cookie: "MUSIC_U=abc"))
        let service = NetEaseAuthService(sessionStore: store, qrLoginProvider: StubQRLoginProvider(result: .waiting))

        let state = await service.currentState()

        try expectEqual(state, .authenticated(userID: "42"))
    }

    static func testQRCodeSuccessPersistsSessionAndAuthenticates() async throws {
        let store = InMemorySessionStore()
        let session = NetEaseSession(userID: "42", cookie: "MUSIC_U=abc")
        let service = NetEaseAuthService(sessionStore: store, qrLoginProvider: StubQRLoginProvider(result: .confirmed(session)))

        let state = await service.pollQRCode()
        let savedSession = try await store.load()

        try expectEqual(state, .authenticated(userID: "42"))
        try expectEqual(savedSession, session)
    }

    static func testExpiredQRCodeReturnsFailedState() async throws {
        let service = NetEaseAuthService(sessionStore: InMemorySessionStore(), qrLoginProvider: StubQRLoginProvider(result: .expired))

        let state = await service.pollQRCode()

        try expectEqual(state, .failed("二维码已过期"))
    }
}

private struct StubQRLoginProvider: QRLoginProviding {
    let result: QRLoginPollResult

    func poll() async throws -> QRLoginPollResult {
        result
    }
}
