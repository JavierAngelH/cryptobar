import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = PriceViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItem()

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        viewModel.start()

        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            viewModel.refreshIfStale(force: false)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "CryptoBar")?
            .withSymbolConfiguration(config)

        if viewModel.quotes.isEmpty {
            button.title = ""
        } else {
            button.title = "  \(viewModel.menuBarSummary())"
        }

        if let first = viewModel.quotes.first, let change = first.change24h {
            button.contentTintColor = change >= 0
                ? NSColor.systemGreen.withAlphaComponent(0.85)
                : NSColor.systemRed.withAlphaComponent(0.85)
        } else {
            button.contentTintColor = nil
        }
    }
}
