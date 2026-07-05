import AppKit
import CloudLyricBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: CloudLyricBarViewModel?
    private var statusBarController: StatusBarController?
    private var lyricRefreshTimer: Timer?
    private var apiServerManager: NetEaseAPIServerManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let apiBaseURL = URL(string: "http://localhost:3000")!
        let apiServerManager = NetEaseAPIServerManager(baseURL: apiBaseURL)
        self.apiServerManager = apiServerManager
        Task.detached {
            _ = await apiServerManager.ensureRunning()
        }

        let api = URLSessionNetEaseAPIClient(baseURL: apiBaseURL)
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
        let popoverController = PopoverController(viewModel: viewModel) {
            NSApplication.shared.terminate(nil)
        }
        self.viewModel = viewModel
        statusBarController = StatusBarController(viewModel: viewModel, popoverController: popoverController)
        lyricRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak viewModel] _ in
            Task { @MainActor in
                await viewModel?.refreshEstimatedPlayback()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lyricRefreshTimer?.invalidate()
    }
}
