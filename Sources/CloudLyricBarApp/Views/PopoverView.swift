import CloudLyricBarCore
import SwiftUI

struct PopoverView: View {
    private static let width: CGFloat = 360
    private static let height: CGFloat = 292

    @ObservedObject var viewModel: CloudLyricBarViewModel
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            currentSongHeader
            playbackControls
            lyricContext
            statusMessage
            quitButton
        }
        .padding(18)
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        .clipped()
    }

    private var currentSongHeader: some View {
        HStack(spacing: 10) {
            artworkView

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSong?.title ?? "未播放")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(viewModel.currentSong?.artist ?? "打开网易云音乐后开始同步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 52)
    }

    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.18))

            if let artworkURL = viewModel.currentSong?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
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
        .frame(height: 28)
    }

    private var quitButton: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Spacer(minLength: 0)
                Button(action: quitAction) {
                    Label("退出", systemImage: "power")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .bottom)
    }

    private var lyricContext: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.lyricContext.previous?.text ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .leading)
            Text(viewModel.lyricContext.current?.text ?? "暂无同步歌词")
                .font(.body)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
            Text(viewModel.lyricContext.next?.text ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let message = viewModel.message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18, alignment: .leading)
        } else {
            Text(" ")
                .font(.caption)
                .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18, alignment: .leading)
        }
    }
}
