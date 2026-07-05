import Foundation

public protocol SongAudioPlaying: Sendable {
    func play(song: Song, streamURL: URL) async throws
    func send(_ command: PlaybackCommand) async throws
    func snapshot() async -> NowPlayingSnapshot
}
