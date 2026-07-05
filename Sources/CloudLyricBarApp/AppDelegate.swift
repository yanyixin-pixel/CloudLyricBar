import AppKit
import CloudLyricBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: CloudLyricBarViewModel?
    private var statusBarController: StatusBarController?
    private var lyricRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let api = URLSessionNetEaseAPIClient(baseURL: URL(string: "http://localhost:3000")!)
        let permissionCoordinator = PermissionCoordinator(accessibilityProbe: MacAccessibilityPermissionProbe())
        let playback = PlaybackControlService(strategies: [
            NetEaseDeepLinkStrategy { url in
                NSWorkspace.shared.open(url)
            },
            AccessibilityPlaybackStrategy(permissionCoordinator: permissionCoordinator)
        ])
        let nowPlayingProvider = ProcessNowPlayingService()
        let viewModel = CloudLyricBarViewModel(
            apiClient: api,
            playbackControl: playback,
            permissionCoordinator: permissionCoordinator,
            nowPlayingProvider: nowPlayingProvider
        )
        let popoverController = PopoverController(viewModel: viewModel)
        self.viewModel = viewModel
        statusBarController = StatusBarController(viewModel: viewModel, popoverController: popoverController)
        lyricRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak viewModel] _ in
            Task { @MainActor in
                await viewModel?.refreshEstimatedPlayback()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lyricRefreshTimer?.invalidate()
    }
}
