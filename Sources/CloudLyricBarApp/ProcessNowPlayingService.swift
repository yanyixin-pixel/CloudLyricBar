import CloudLyricBarCore
import Foundation

final class ProcessNowPlayingService: NowPlayingProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var latestSnapshot = NowPlayingSnapshot(song: nil, playback: .stopped, position: nil)
    private var outputBuffer = ""
    private var process: Process?

    init() {
        startProbe()
    }

    deinit {
        process?.terminate()
    }

    func snapshot() async -> NowPlayingSnapshot {
        snapshotSync()
    }

    private func snapshotSync() -> NowPlayingSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return latestSnapshot
    }

    private func startProbe() {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloudlyricbar-nowplaying-probe.swift")

        do {
            try probeScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swift", scriptURL.path]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }

            self?.consume(text)
        }

        do {
            try process.run()
            self.process = process
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
    }

    private func consume(_ text: String) {
        lock.lock()
        outputBuffer += text
        let parts = outputBuffer.split(separator: "\n", omittingEmptySubsequences: false)
        outputBuffer = parts.last.map(String.init) ?? ""
        let lines = parts.dropLast().map(String.init)
        lock.unlock()

        for line in lines {
            guard let snapshot = Self.decode(line) else {
                continue
            }

            lock.lock()
            latestSnapshot = snapshot
            lock.unlock()
        }
    }

    private static func decode(_ line: String) -> NowPlayingSnapshot? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        guard let title = object["title"] as? String, !title.isEmpty else {
            return NowPlayingSnapshot(song: nil, playback: .stopped, position: nil)
        }

        let artist = object["artist"] as? String ?? ""
        let position = object["position"] as? TimeInterval
        let rate = object["playbackRate"] as? Double ?? 0
        let timestamp = (object["timestamp"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))

        return ExternalNowPlayingPayload(
            title: title,
            artist: artist,
            elapsedTime: position,
            playbackRate: rate,
            timestamp: timestamp
        ).snapshot()
    }

    private var probeScript: String {
        """
        import Foundation
        import Darwin

        typealias Callback = @convention(block) (CFDictionary?) -> Void
        typealias Function = @convention(c) (DispatchQueue, @escaping Callback) -> Void

        func emit(_ info: CFDictionary?) {
            var payload: [String: Any] = [:]
            if let info {
                let dictionary = info as NSDictionary
                payload["title"] = dictionary["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                payload["artist"] = dictionary["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                payload["position"] = dictionary["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
                payload["playbackRate"] = dictionary["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
                if let timestamp = dictionary["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                    payload["timestamp"] = timestamp.timeIntervalSince1970
                }
            } else {
                payload["title"] = ""
            }

            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let line = String(data: data, encoding: .utf8) {
                print(line)
                fflush(stdout)
            }
        }

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else {
            while true {
                emit(nil)
                Thread.sleep(forTimeInterval: 1)
            }
        }

        let getNowPlayingInfo = unsafeBitCast(symbol, to: Function.self)

        while true {
            let semaphore = DispatchSemaphore(value: 0)
            getNowPlayingInfo(DispatchQueue.main) { info in
                emit(info)
                semaphore.signal()
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            _ = semaphore.wait(timeout: .now() + 2)
            Thread.sleep(forTimeInterval: 0.25)
        }
        """
    }
}
