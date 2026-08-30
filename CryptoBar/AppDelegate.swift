import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: PriceViewModel!
    private var statusUpdateTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            installMenuBar()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            statusUpdateTask?.cancel()
            viewModel?.stop()
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        MainActor.assumeIsolated {
            togglePopoverOnMainActor(sender)
        }
    }

    @MainActor
    private func installMenuBar() {
        viewModel = PriceViewModel()

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

        statusUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                updateStatusItem()
            }
        }
    }

    @MainActor
    private func togglePopoverOnMainActor(_ sender: AnyObject?) {
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
