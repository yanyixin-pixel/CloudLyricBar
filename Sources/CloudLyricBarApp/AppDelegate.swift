import AppKit
import CloudLyricBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var lyricRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let api = URLSessionNetEaseAPIClient(baseURL: URL(string: "http://localhost:3000")!)
        let permissionCoordinator = PermissionCoordinator(accessibilityProbe: MacAccessibilityPermissionProbe())
        let playback = PlaybackControlService(strategies: [
            NetEaseDeepLinkStrategy { url in
                NSWorkspace.shared.open(url)
            },
            AccessibilityPlaybackStrategy(permissionCoordinator: permissionCoordinator)
        ])
        let viewModel = CloudLyricBarViewModel(
            apiClient: api,
            playbackControl: playback,
            permissionCoordinator: permissionCoordinator
        )
        let popoverController = PopoverController(viewModel: viewModel)
        statusBarController = StatusBarController(viewModel: viewModel, popoverController: popoverController)
        lyricRefreshTask = Task { @MainActor [weak viewModel] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await viewModel?.refreshEstimatedPlayback()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lyricRefreshTask?.cancel()
    }
}
