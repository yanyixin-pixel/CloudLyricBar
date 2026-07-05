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
    private let postPlayPause: @Sendable () async throws -> Void

    init(
        permissionCoordinator: PermissionCoordinator,
        postPlayPause: @escaping @Sendable () async throws -> Void = AccessibilityPlaybackStrategy.postPlayPauseMediaKey
    ) {
        self.permissionCoordinator = permissionCoordinator
        self.postPlayPause = postPlayPause
    }

    func canSend(_ command: PlaybackCommand) async -> Bool {
        guard command == .playPause else {
            return false
        }

        return await permissionCoordinator.currentAccessibilityState() == .trusted
    }

    func send(_ command: PlaybackCommand) async throws {
        guard await canSend(command) else {
            throw PlaybackControlError.noAvailableStrategy
        }

        try await postPlayPause()
    }

    private static func postPlayPauseMediaKey() async throws {
        try await MainActor.run {
            try postMediaKey(NX_KEYTYPE_PLAY)
        }
    }

    @MainActor
    private static func postMediaKey(_ key: Int32) throws {
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
