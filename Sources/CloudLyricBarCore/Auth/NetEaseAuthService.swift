import Foundation

public enum AuthState: Equatable, Sendable {
    case signedOut
    case waitingForScan
    case authenticated(userID: String)
    case failed(String)
}

public enum QRLoginPollResult: Equatable, Sendable {
    case waiting
    case expired
    case confirmed(NetEaseSession)
}

public struct QRCodeLogin: Equatable, Sendable {
    public let key: String
    public let url: URL

    public init(key: String, url: URL) {
        self.key = key
        self.url = url
    }
}

public protocol QRLoginProviding: Sendable {
    func createQRCode() async throws -> QRCodeLogin
    func poll(key: String) async throws -> QRLoginPollResult
}

public actor NetEaseAuthService {
    private let sessionStore: any SessionStore
    private let qrLoginProvider: any QRLoginProviding
    private var state: AuthState = .signedOut

    public init(sessionStore: any SessionStore, qrLoginProvider: any QRLoginProviding) {
        self.sessionStore = sessionStore
        self.qrLoginProvider = qrLoginProvider
    }

    public func currentState() async -> AuthState {
        do {
            if let session = try await sessionStore.load() {
                state = .authenticated(userID: session.userID)
            } else {
                state = .signedOut
            }
        } catch {
            state = .failed("无法读取登录状态")
        }

        return state
    }

    public func createQRCode() async throws -> QRCodeLogin {
        try await qrLoginProvider.createQRCode()
    }

    public func pollQRCode(key: String) async throws -> AuthState {
        switch try await qrLoginProvider.poll(key: key) {
        case .waiting:
            state = .waitingForScan
        case .expired:
            state = .failed("二维码已过期")
        case .confirmed(let session):
            try await sessionStore.save(session)
            state = .authenticated(userID: session.userID)
        }

        return state
    }
}
