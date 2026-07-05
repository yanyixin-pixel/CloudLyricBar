import AVFoundation
import CloudLyricBarCore
import Foundation

actor AVFoundationSongAudioPlayer: SongAudioPlaying {
    private var player: AVPlayer?
    private var currentSong: Song?
    private var playback: PlaybackState = .stopped

    func play(song: Song, streamURL: URL) async throws {
        let player = AVPlayer(playerItem: AVPlayerItem(url: streamURL))
        self.player = player
        currentSong = song
        playback = .playing
        player.play()
    }

    func send(_ command: PlaybackCommand) async throws {
        guard let player else {
            throw PlaybackControlError.noAvailableStrategy
        }

        switch command {
        case .playPause:
            if playback == .playing {
                player.pause()
                playback = .paused
            } else {
                player.play()
                playback = .playing
            }
        case .previous:
            await seek(player, to: .zero)
            player.play()
            playback = .playing
        case .next, .openSong:
            throw PlaybackControlError.noAvailableStrategy
        }
    }

    func snapshot() async -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            song: currentSong,
            playback: playback,
            position: currentPosition(),
            capturedAt: Date()
        )
    }

    private func currentPosition() -> TimeInterval? {
        guard let player else {
            return nil
        }

        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    private func seek(_ player: AVPlayer, to time: CMTime) async {
        await withCheckedContinuation { continuation in
            player.seek(to: time) { _ in
                continuation.resume()
            }
        }
    }
}
