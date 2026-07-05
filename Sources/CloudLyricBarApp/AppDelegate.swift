import AppKit
import CloudLyricBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let api = URLSessionNetEaseAPIClient(baseURL: URL(string: "http://localhost:3000")!)
        let viewModel = CloudLyricBarViewModel(apiClient: api)
        let popoverController = PopoverController(viewModel: viewModel)
        statusBarController = StatusBarController(viewModel: viewModel, popoverController: popoverController)
    }
}
