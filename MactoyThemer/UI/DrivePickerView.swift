import AppKit

/// The shared "Device" row docked above the tabs. Holds no state of its own —
/// every action calls into the injected `VolumeManager`, and the popup is
/// rebuilt whenever `.volumeManagerDidChange` fires, so it stays in sync no
/// matter what triggered the change.
final class DrivePickerView: NSView, NSMenuDelegate {
    private let volumeManager: VolumeManager
    private let label = NSTextField(labelWithString: "")
    private let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let chooseButton = NSButton(title: "", target: nil, action: nil)

    init(volumeManager: VolumeManager) {
        self.volumeManager = volumeManager
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildLayout()
        popUp.menu?.delegate = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildMenu), name: .volumeManagerDidChange, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyLocalizedStrings), name: .appLanguageDidChange, object: nil
        )
        applyLocalizedStrings()
        rebuildMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildLayout() {
        let icon = NSImageView()
        icon.image = InterfaceStyle.icon("externaldrive", fallback: NSImage.computerName)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        // Only the popup stretches or truncates as the window width changes.
        for control in [label, chooseButton] {
            control.setContentHuggingPriority(.required, for: .horizontal)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        popUp.setContentHuggingPriority(.defaultLow, for: .horizontal)
        popUp.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        popUp.cell?.lineBreakMode = .byTruncatingMiddle
        InterfaceStyle.decorate(chooseButton, symbol: "folder", fallback: NSImage.folderName)
        for subview in [icon, label, popUp, chooseButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        popUp.target = self
        popUp.action = #selector(selectionChanged)
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseTapped)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),

            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            popUp.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            popUp.centerYAnchor.constraint(equalTo: centerYAnchor),
            popUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            popUp.trailingAnchor.constraint(equalTo: chooseButton.leadingAnchor, constant: -8),

            chooseButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            chooseButton.centerYAnchor.constraint(equalTo: popUp.centerYAnchor)
        ])
    }

    /// Also re-runs `rebuildMenu` via the language notification so the
    /// "no device" placeholder and the not-detected suffix follow along.
    @objc private func applyLocalizedStrings() {
        label.stringValue = L.t(.deviceLabel)
        chooseButton.title = L.t(.browse)
        chooseButton.toolTip = L.t(.browseTooltip)
        popUp.setAccessibilityLabel(L.t(.deviceAccessibility))
        rebuildMenu()
    }

    @objc private func rebuildMenu() {
        popUp.removeAllItems()

        let volumes = volumeManager.volumes
        guard !volumes.isEmpty else {
            popUp.addItem(withTitle: L.t(.noDeviceFound))
            popUp.isEnabled = false
            return
        }

        popUp.isEnabled = true
        for volume in volumes {
            let item = NSMenuItem(title: volume.name, action: nil, keyEquivalent: "")
            item.representedObject = volume
            // Non-Ventoy-named drives are selectable but flagged, so picking
            // the wrong disk takes a deliberate act.
            if !volume.isAutoDetected {
                item.attributedTitle = NSAttributedString(
                    string: volume.name + L.t(.notDetectedSuffix),
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                )
            }
            popUp.menu?.addItem(item)
        }

        if let selected = volumeManager.selectedVolume, let index = volumes.firstIndex(of: selected) {
            popUp.selectItem(at: index)
        } else {
            popUp.select(nil)
        }
    }

    @objc private func selectionChanged() {
        guard let volume = popUp.selectedItem?.representedObject as? VentoyVolume else { return }
        volumeManager.select(volume)
    }

    @objc private func chooseTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        panel.prompt = L.t(.choosePrompt)
        panel.message = L.t(.chooseMessage)

        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.volumeManager.selectManualLocation(url)
        }
    }

    // MARK: - NSMenuDelegate

    /// Belt-and-braces on top of the workspace mount notifications. Cheap:
    /// `rescanVolumes` returns without notifying when nothing changed, so
    /// this no longer rebuilds the menu mid-open.
    func menuWillOpen(_ menu: NSMenu) {
        volumeManager.rescanVolumes()
    }
}
