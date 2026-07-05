import AppKit
import CloudLyricBarCore
import Combine

@MainActor
final class StatusBarController: NSObject {
    private static let statusItemLength: CGFloat = 340
    private static let visibleCharacterCount = 32
    private static let leadingPauseTicks = 3
    private static let trailingPauseTicks = 3

    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private var cancellables = Set<AnyCancellable>()
    private var marqueeState = MarqueeTitleState()

    init(viewModel: CloudLyricBarViewModel, popoverController: PopoverController) {
        statusItem = NSStatusBar.system.statusItem(withLength: Self.statusItemLength)
        self.popoverController = popoverController
        super.init()

        if let button = statusItem.button {
            marqueeState.updateTitle(viewModel.menuBarTitle)
            button.title = viewModel.menuBarTitle
            button.toolTip = viewModel.menuBarTitle
            button.cell?.lineBreakMode = .byClipping
            button.cell?.wraps = false
            button.target = self
            button.action = #selector(togglePopover)
        }

        viewModel.$menuBarTitle
            .receive(on: RunLoop.main)
            .sink { [weak self] title in
                self?.updateFullTitle(title)
            }
            .store(in: &cancellables)

        Timer.publish(every: 0.45, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.advanceMarquee()
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button)
    }

    private func updateFullTitle(_ title: String) {
        marqueeState.updateTitle(title)
        renderTitle()
    }

    private func advanceMarquee() {
        marqueeState.advance()
        renderTitle()
    }

    private func renderTitle() {
        let frame = marqueeState.frame(
            visibleCharacterCount: Self.visibleCharacterCount,
            leadingPauseTicks: Self.leadingPauseTicks,
            trailingPauseTicks: Self.trailingPauseTicks
        )
        statusItem.button?.title = frame.text
        statusItem.button?.toolTip = marqueeState.title
    }
}
