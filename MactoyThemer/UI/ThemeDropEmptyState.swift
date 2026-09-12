import AppKit

/// A visual hint that lets pointer and Finder drag events reach the table below.
final class ThemeDropEmptyState: NSView {
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let icon = NSImageView()
        icon.image = InterfaceStyle.icon("square.and.arrow.down.on.square", fallback: NSImage.multipleDocumentsName)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.alphaValue = 0.55
        title.font = .systemFont(ofSize: 13, weight: .medium)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        applyLocalizedStrings()
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyLocalizedStrings), name: .appLanguageDidChange, object: nil
        )
        let stack = NSStackView(views: [icon, title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applyLocalizedStrings() {
        title.stringValue = L.t(.dropThemesHere)
        subtitle.stringValue = L.t(.archivesOrFolders)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
