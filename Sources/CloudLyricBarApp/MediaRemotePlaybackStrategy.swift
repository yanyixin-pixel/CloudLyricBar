import CloudLyricBarCore
import Foundation

struct MediaRemotePlaybackStrategy: PlaybackControlStrategy {
    func canSend(_ command: PlaybackCommand) async -> Bool {
        Self.mediaRemoteCommand(for: command) != nil && Self.sendCommandFunction() != nil
    }

    func send(_ command: PlaybackCommand) async throws {
        guard let remoteCommand = Self.mediaRemoteCommand(for: command),
              let sendCommand = Self.sendCommandFunction()
        else {
            throw PlaybackControlError.noAvailableStrategy
        }

        sendCommand(remoteCommand, nil)
    }

    private static func mediaRemoteCommand(for command: PlaybackCommand) -> Int32? {
        switch command {
        case .playPause:
            return 2
        case .next:
            return 4
        case .previous:
            return 5
        case .openSong:
            return nil
        }
    }

    private static func sendCommandFunction() -> SendCommandFunction? {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else {
            return nil
        }

        return unsafeBitCast(symbol, to: SendCommandFunction.self)
    }
}

private typealias SendCommandFunction = @convention(c) (Int32, CFDictionary?) -> Void
