import AppKit

enum AppLifecycle {
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
