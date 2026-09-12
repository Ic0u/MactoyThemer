import AppKit

/// Creates every visible app icon from SF Symbols on supported macOS versions.
/// AppKit template images are retained only as compatibility fallbacks for the
/// app's macOS 10.13 deployment target, where SF Symbols are unavailable.
enum InterfaceStyle {
    static func icon(_ symbol: String, fallback: NSImage.Name) -> NSImage? {
        if #available(macOS 11.0, *),
           let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            return image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)) ?? image
        }
        let image = NSImage(named: fallback)?.copy() as? NSImage
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    static func decorate(_ button: NSButton, symbol: String, fallback: NSImage.Name) {
        button.image = icon(symbol, fallback: fallback)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.setAccessibilityLabel(button.title)
    }

    /// A button with only a symbol — no visible title — for a secondary
    /// action next to a list (add/remove/clear), where a text label next to
    /// an icon is redundant. `accessibilityLabel` replaces the title VoiceOver
    /// would otherwise have read, since there no longer is one.
    static func iconOnly(_ button: NSButton, symbol: String, fallback: NSImage.Name, accessibilityLabel: String) {
        button.title = ""
        button.image = icon(symbol, fallback: fallback)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel
    }

    static func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }
}
