import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApplication.shared.windows.first else { return }
        let targetSize = NSSize(width: 575, height: 760)
        window.setContentSize(targetSize)
        window.setFrame(
            NSRect(origin: window.frame.origin, size: targetSize),
            display: true
        )
        window.minSize = NSSize(width: 545, height: 700)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
    }
}
