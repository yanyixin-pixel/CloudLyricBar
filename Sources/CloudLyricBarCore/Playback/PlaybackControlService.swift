import Foundation

public enum PlaybackCommand: Equatable, Sendable {
    case playPause
    case previous
    case next
    case openSong(id: String)
}

public enum PlaybackControlError: Error, Equatable {
    case noAvailableStrategy
}

public protocol PlaybackControlStrategy: Sendable {
    func canSend(_ command: PlaybackCommand) async -> Bool
    func send(_ command: PlaybackCommand) async throws
}

public actor PlaybackControlService {
    private let strategies: [any PlaybackControlStrategy]
    private var tail: Task<Void, Never>?

    public init(strategies: [any PlaybackControlStrategy]) {
        self.strategies = strategies
    }

    public func send(_ command: PlaybackCommand) async throws {
        let previous = tail
        let operation = Task { [strategies] in
            if let previous {
                await previous.value
            }

            try await Self.send(command, using: strategies)
        }

        tail = Task {
            _ = await operation.result
        }

        try await operation.value
    }

    private static func send(
        _ command: PlaybackCommand,
        using strategies: [any PlaybackControlStrategy]
    ) async throws {
        for strategy in strategies {
            guard await strategy.canSend(command) else {
                continue
            }

            try await strategy.send(command)
            return
        }

        throw PlaybackControlError.noAvailableStrategy
    }
}

public struct NetEaseDeepLinkStrategy: PlaybackControlStrategy {
    private let opener: @Sendable (URL) -> Void

    public init(opener: @escaping @Sendable (URL) -> Void) {
        self.opener = opener
    }

    public func canSend(_ command: PlaybackCommand) async -> Bool {
        switch command {
        case let .openSong(id):
            Self.isValidSongID(id)
        case .playPause, .previous, .next:
            false
        }
    }

    public func send(_ command: PlaybackCommand) async throws {
        guard case let .openSong(id) = command else {
            throw PlaybackControlError.noAvailableStrategy
        }

        guard Self.isValidSongID(id), let url = URL(string: "orpheus://song/\(id)") else {
            throw PlaybackControlError.noAvailableStrategy
        }

        opener(url)
    }

    private static func isValidSongID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.allSatisfy { byte in
            (48...57).contains(byte)
        }
    }
}
