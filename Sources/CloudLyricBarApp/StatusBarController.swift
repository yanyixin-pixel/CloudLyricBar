import AppKit
import CloudLyricBarCore
import Combine

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: CloudLyricBarViewModel, popoverController: PopoverController) {
        statusItem = NSStatusBar.system.statusItem(withLength: 220)
        self.popoverController = popoverController
        super.init()

        if let button = statusItem.button {
            button.title = viewModel.menuBarTitle
            button.target = self
            button.action = #selector(togglePopover)
        }

        viewModel.$menuBarTitle
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.statusItem.button?.title = title
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)
    }
}
