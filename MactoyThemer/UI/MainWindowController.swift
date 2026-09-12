import AppKit

final class MainWindowController: NSWindowController {
    init(volumeManager: VolumeManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MactoyThemer"
        window.minSize = NSSize(width: 420, height: 320)
        window.contentViewController = RootViewController(volumeManager: volumeManager)
        window.center()

        // This window is built from scratch on every launch and holds no state
        // worth persisting — the drive list is rescanned and the config re-read
        // each time. Leaving restoration on made AppKit try to rebuild it from
        // saved state with no restoration class registered, logging
        // "restoreWindowWithIdentifier … Unable to find className=(null)".
        window.isRestorable = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
