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
    private let service: String
    private let account: String

    public init(service: String = "CloudLyricBar.NetEaseSession", account: String = "default") {
        self.service = service
        self.account = account
    }

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

            if addStatus == errSecDuplicateItem {
                try updateExistingItem(query: query, attributes: attributes)
                return
            }

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
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }

    private func updateExistingItem(query: [CFString: Any], attributes: [CFString: Any]) throws {
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
