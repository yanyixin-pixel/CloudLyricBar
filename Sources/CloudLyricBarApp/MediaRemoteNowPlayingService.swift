import CloudLyricBarCore
import Darwin
import Foundation

actor MediaRemoteNowPlayingService: NowPlayingProviding {
    private typealias NowPlayingInfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetNowPlayingInfoFunction = @convention(c) (
        DispatchQueue,
        @escaping NowPlayingInfoCallback
    ) -> Void

    private let getNowPlayingInfo: GetNowPlayingInfoFunction?

    init(
        frameworkPath: String = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    ) {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo")
        else {
            getNowPlayingInfo = nil
            return
        }

        getNowPlayingInfo = unsafeBitCast(symbol, to: GetNowPlayingInfoFunction.self)
    }

    func snapshot() async -> NowPlayingSnapshot {
        guard let getNowPlayingInfo else {
            return NowPlayingSnapshot(song: nil, playback: .stopped, position: nil)
        }

        return await withCheckedContinuation { continuation in
            getNowPlayingInfo(DispatchQueue.main) { info in
                continuation.resume(returning: Self.snapshot(from: info))
            }
        }
    }

    private static func snapshot(from info: CFDictionary?) -> NowPlayingSnapshot {
        guard let dictionary = info as? [AnyHashable: Any],
              let title = stringValue(in: dictionary, matching: ["Title"]),
              !title.isEmpty
        else {
            return NowPlayingSnapshot(song: nil, playback: .stopped, position: nil)
        }

        let artist = stringValue(in: dictionary, matching: ["Artist"]) ?? ""
        let elapsedTime = numberValue(in: dictionary, matching: ["ElapsedTime"])
        let playbackRate = numberValue(in: dictionary, matching: ["PlaybackRate"]) ?? 0
        let playback: PlaybackState = playbackRate > 0.01 ? .playing : .paused
        let song = Song(
            id: "external:mediaremote:\(title):\(artist)",
            title: title,
            artist: artist
        )

        return NowPlayingSnapshot(
            song: song,
            playback: playback,
            position: elapsedTime,
            capturedAt: Date()
        )
    }

    private static func stringValue(
        in dictionary: [AnyHashable: Any],
        matching keyParts: [String]
    ) -> String? {
        for (key, value) in dictionary where keyMatches(key, keyParts: keyParts) {
            if let string = value as? String {
                return string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func numberValue(
        in dictionary: [AnyHashable: Any],
        matching keyParts: [String]
    ) -> TimeInterval? {
        for (key, value) in dictionary where keyMatches(key, keyParts: keyParts) {
            if let number = value as? NSNumber {
                return number.doubleValue
            }

            if let double = value as? Double {
                return double
            }
        }

        return nil
    }

    private static func keyMatches(_ key: AnyHashable, keyParts: [String]) -> Bool {
        let keyText = String(describing: key)
        return keyParts.allSatisfy { keyText.localizedCaseInsensitiveContains($0) }
    }
}
