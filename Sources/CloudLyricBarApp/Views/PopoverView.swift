import CloudLyricBarCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: CloudLyricBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            currentSongHeader
            playbackControls
            lyricContext
            statusMessage
        }
        .padding(14)
        .frame(width: 360, height: 220)
    }

    private var currentSongHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSong?.title ?? "未播放")
                    .font(.headline)
                    .lineLimit(1)
                Text(viewModel.currentSong?.artist ?? "打开网易云音乐后开始同步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var playbackControls: some View {
        HStack {
            Button(action: { Task { await viewModel.sendPlaybackCommand(.previous) } }) {
                Image(systemName: "backward.fill")
            }
            Button(action: { Task { await viewModel.sendPlaybackCommand(.playPause) } }) {
                Image(systemName: viewModel.playback == .playing ? "pause.fill" : "play.fill")
            }
            Button(action: { Task { await viewModel.sendPlaybackCommand(.next) } }) {
                Image(systemName: "forward.fill")
            }
        }
        .buttonStyle(.borderless)
    }

    private var lyricContext: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.lyricContext.previous?.text ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(viewModel.lyricContext.current?.text ?? "暂无同步歌词")
                .font(.body)
                .lineLimit(2)
            Text(viewModel.lyricContext.next?.text ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = viewModel.message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
