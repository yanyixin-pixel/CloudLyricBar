import AppKit
import ApplicationServices
import CloudLyricBarCore
import IOKit.hidsystem

struct MacAccessibilityPermissionProbe: AccessibilityPermissionProbing {
    func isTrusted() async -> Bool {
        AXIsProcessTrusted()
    }

    func requestTrustPrompt() async {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }
}

struct AccessibilityPlaybackStrategy: PlaybackControlStrategy {
    private let permissionCoordinator: PermissionCoordinator
    private let postMediaKey: @Sendable (PlaybackCommand) async throws -> Void

    init(
        permissionCoordinator: PermissionCoordinator,
        postMediaKey: @escaping @Sendable (PlaybackCommand) async throws -> Void = AccessibilityPlaybackStrategy.postMediaKey
    ) {
        self.permissionCoordinator = permissionCoordinator
        self.postMediaKey = postMediaKey
    }

    func canSend(_ command: PlaybackCommand) async -> Bool {
        guard Self.mediaKeyType(for: command) != nil else {
            return false
        }

        return await permissionCoordinator.currentAccessibilityState() == .trusted
    }

    func send(_ command: PlaybackCommand) async throws {
        guard await canSend(command) else {
            throw PlaybackControlError.noAvailableStrategy
        }

        try await postMediaKey(command)
    }

    private static func postMediaKey(_ command: PlaybackCommand) async throws {
        guard let key = mediaKeyType(for: command) else {
            throw PlaybackControlError.noAvailableStrategy
        }

        try await MainActor.run {
            try postMediaKeyEvent(key)
        }
    }

    private static func mediaKeyType(for command: PlaybackCommand) -> Int32? {
        switch command {
        case .playPause:
            return NX_KEYTYPE_PLAY
        case .previous:
            return NX_KEYTYPE_PREVIOUS
        case .next:
            return NX_KEYTYPE_NEXT
        case .openSong:
            return nil
        }
    }

    @MainActor
    private static func postMediaKeyEvent(_ key: Int32) throws {
        let keyCode = Int(key)
        let eventFlags = NSEvent.ModifierFlags(rawValue: 0xA00)
        let keyDownData = (keyCode << 16) | (0xA << 8)
        let keyUpData = (keyCode << 16) | (0xB << 8)

        guard
            let keyDown = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: eventFlags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: keyDownData,
                data2: -1
            )?.cgEvent,
            let keyUp = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: eventFlags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: keyUpData,
                data2: -1
            )?.cgEvent
        else {
            throw PlaybackControlError.commandFailed
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
