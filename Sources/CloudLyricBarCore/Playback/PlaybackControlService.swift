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

    public init(strategies: [any PlaybackControlStrategy]) {
        self.strategies = strategies
    }

    public func send(_ command: PlaybackCommand) async throws {
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
        case .openSong:
            true
        case .playPause, .previous, .next:
            false
        }
    }

    public func send(_ command: PlaybackCommand) async throws {
        guard case let .openSong(id) = command else {
            throw PlaybackControlError.noAvailableStrategy
        }

        opener(URL(string: "orpheus://song/\(id)")!)
    }
}
