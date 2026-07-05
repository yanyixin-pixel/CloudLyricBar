import Foundation
import Security

public struct NetEaseSession: Codable, Equatable, Sendable {
    public let userID: String
    public let cookie: String

    public init(userID: String, cookie: String) {
        self.userID = userID
        self.cookie = cookie
    }
}

public enum KeychainError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)
}

public protocol SessionStore: Sendable {
    func load() async throws -> NetEaseSession?
    func save(_ session: NetEaseSession) async throws
    func clear() async throws
}

public actor InMemorySessionStore: SessionStore {
    private var session: NetEaseSession?

    public init(session: NetEaseSession? = nil) {
        self.session = session
    }

    public func load() async throws -> NetEaseSession? {
        session
    }

    public func save(_ session: NetEaseSession) async throws {
        self.session = session
    }

    public func clear() async throws {
        session = nil
    }
}

public struct KeychainSessionStore: SessionStore {
    public init() {}

    public func load() async throws -> NetEaseSession? {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError.unhandledStatus(status)
            }

            return try JSONDecoder().decode(NetEaseSession.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func save(_ session: NetEaseSession) async throws {
        let data = try JSONEncoder().encode(session)
        let query = baseQuery()
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        default:
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    public func clear() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "CloudLyricBar.NetEaseSession",
            kSecAttrAccount: "default"
        ]
    }
}
