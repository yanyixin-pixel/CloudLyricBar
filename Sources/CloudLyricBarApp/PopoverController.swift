import AppKit
import CloudLyricBarCore
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover: NSPopover
    private var outsideClickMonitor: Any?

    init(viewModel: CloudLyricBarViewModel, quitAction: @escaping () -> Void) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 292)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel, quitAction: quitAction)
        )
        super.init()
        popover.delegate = self
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startOutsideClickMonitor()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
    }

    private func close() {
        popover.performClose(nil)
        stopOutsideClickMonitor()
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }

    private func stopOutsideClickMonitor() {
        guard let outsideClickMonitor else {
            return
        }

        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}
