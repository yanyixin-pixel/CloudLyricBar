import AppKit
import CloudLyricBarCore
import Combine

@MainActor
final class StatusBarController: NSObject {
    private static let statusItemLength: CGFloat = 340
    private static let horizontalTextInset: CGFloat = 18
    private static let leadingPauseTicks = 1
    private static let trailingPauseTicks = 0

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

        Timer.publish(every: 0.18, on: .main, in: .common)
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
        guard let button = statusItem.button else {
            return
        }

        let maxDisplayWidth = max(24, button.bounds.width - Self.horizontalTextInset)
        let font = button.font ?? NSFont.menuBarFont(ofSize: 0)
        let frame = marqueeState.pixelFrame(
            maxDisplayWidth: Double(maxDisplayWidth),
            leadingPauseTicks: Self.leadingPauseTicks,
            trailingPauseTicks: Self.trailingPauseTicks,
            characterWidth: { character in
                Self.width(of: character, font: font)
            }
        )
        button.title = frame.text
        button.toolTip = marqueeState.title
    }

    private static func width(of character: Character, font: NSFont) -> Double {
        let size = String(character).size(withAttributes: [.font: font])
        return Double(ceil(size.width))
    }
}
