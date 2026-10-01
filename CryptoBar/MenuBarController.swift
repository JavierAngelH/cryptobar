import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private let viewModel = PriceViewModel()
    private var menuBarUpdateTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func activate() {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItem()

        popover = NSPopover()
        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel, onOpenSettings: { [weak self] in
                self?.showSettingsWindow()
            })
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        viewModel.start()
        startMenuBarUpdateLoop()
    }

    func deactivate() {
        menuBarUpdateTask?.cancel()
        settingsWindow?.close()
        settingsWindow = nil
        viewModel.stop()
    }

    private func startMenuBarUpdateLoop() {
        menuBarUpdateTask?.cancel()
        menuBarUpdateTask = Task {
            while !Task.isCancelled {
                let tick = menuBarTickInterval
                try? await Task.sleep(for: .seconds(tick))
                guard !Task.isCancelled else { return }

                if viewModel.menuBarRotationInterval > 0, viewModel.menuBarSlotCount() > 1 {
                    viewModel.advanceMenuBarDisplay()
                }
                updateStatusItem()
            }
        }
    }

    private var menuBarTickInterval: TimeInterval {
        let rotation = viewModel.menuBarRotationInterval
        if rotation > 0 {
            return rotation
        }
        return 5
    }

    func showSettingsWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(viewModel: viewModel) { [weak self] in
                self?.settingsWindow?.close()
            }
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "CryptoBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 440, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            viewModel.refreshIfStale(force: false)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "CryptoBar")?
            .withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        }

        button.contentTintColor = nil

        if viewModel.menuBarSlotCount() == 0 {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            button.title = ""
            button.attributedTitle = menuBarAttributedTitle(for: button)
        }
    }

    private func menuBarAttributedTitle(for button: NSStatusBarButton) -> NSAttributedString {
        let summary = "  \(viewModel.menuBarSummary())"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let textColor: NSColor
        if let change = viewModel.menuBarPriceChange() {
            textColor = change >= 0
                ? NSColor.systemGreen
                : NSColor.systemRed
        } else {
            textColor = menuBarForegroundColor(for: button)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: font
        ]
        return NSAttributedString(string: summary, attributes: attributes)
    }

    private func menuBarForegroundColor(for button: NSStatusBarButton) -> NSColor {
        switch button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua:
            return .white
        default:
            return .black
        }
    }
}
