import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            MenuBarController.shared.activate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            MenuBarController.shared.deactivate()
        }
    }
}
