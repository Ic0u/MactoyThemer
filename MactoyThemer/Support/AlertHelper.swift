import AppKit

enum AlertHelper {
    /// Must be called on the main thread. Background callers should hop via
    /// `DispatchQueue.main.sync`, which is safe as long as the caller is
    /// never itself running on the main queue.
    static func confirm(title: String, message: String, confirmTitle: String = L.t(.delete), destructive: Bool = true) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = destructive ? .critical : .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: L.t(.cancel))
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func showError(_ message: String, title: String = "Error") {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    static func showInfo(_ message: String, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
