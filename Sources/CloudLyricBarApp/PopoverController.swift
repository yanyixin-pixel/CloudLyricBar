import AppKit
import CloudLyricBarCore
import SwiftUI

@MainActor
final class PopoverController {
    private let popover: NSPopover

    init(viewModel: CloudLyricBarViewModel) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 220)
        popover.contentViewController = NSHostingController(rootView: PopoverView(viewModel: viewModel))
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
