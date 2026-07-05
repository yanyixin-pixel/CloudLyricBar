import AppKit
import CloudLyricBarCore
import SwiftUI

@MainActor
final class PopoverController {
    private let popover: NSPopover

    init(viewModel: CloudLyricBarViewModel, quitAction: @escaping () -> Void) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 248)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel, quitAction: quitAction)
        )
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
