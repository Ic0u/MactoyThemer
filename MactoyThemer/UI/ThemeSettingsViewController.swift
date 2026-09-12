import AppKit

/// Tab 2: which installed theme boots by default, and at what resolution.
final class ThemeSettingsViewController: VolumeAwareViewController {
    private let themeLabel = NSTextField(labelWithString: "")
    private let themePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let resolutionLabel = NSTextField(labelWithString: "")
    private let resolutionPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let applyButton = NSButton(title: "", target: nil, action: nil)

    private let statusLabel = NSTextField(labelWithString: "")

    override func buildLayout() {
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        for label in [themeLabel, resolutionLabel] {
            label.font = .systemFont(ofSize: 12, weight: .medium)
        }
        for subview in [themeLabel, themePopUp, resolutionLabel, resolutionPopUp, statusLabel, applyButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        resolutionPopUp.addItems(withTitles: ThemeDefaults.gfxModes)

        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applyTapped)
        applyButton.keyEquivalent = "\r"

        NSLayoutConstraint.activate([
            themeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            themeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            themePopUp.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 6),
            themePopUp.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            themePopUp.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            resolutionLabel.topAnchor.constraint(equalTo: themePopUp.bottomAnchor, constant: 20),
            resolutionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            resolutionPopUp.topAnchor.constraint(equalTo: resolutionLabel.bottomAnchor, constant: 6),
            resolutionPopUp.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resolutionPopUp.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statusLabel.leadingAnchor.constraint(equalTo: themePopUp.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: applyButton.leadingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            applyButton.widthAnchor.constraint(equalToConstant: 140)
        ])
    }

    override func applyLocalizedStrings() {
        themeLabel.stringValue = L.t(.defaultTheme)
        resolutionLabel.stringValue = L.t(.displayResolution)
        applyButton.title = L.t(.saveSettings)
        themePopUp.setAccessibilityLabel(L.t(.defaultTheme))
        resolutionPopUp.setAccessibilityLabel(L.t(.displayResolution))
    }

    override func volumeStateDidChange() {
        let config = volumeManager.themeConfig
        let names = config.installedThemeNames

        // Row 0 is "Random Theme", so a row index here is exactly Ventoy's
        // 1-based `default_file` value.
        themePopUp.removeAllItems()
        themePopUp.addItem(withTitle: L.t(.randomTheme))
        themePopUp.addItems(withTitles: names)

        themePopUp.selectItem(at: config.defaultThemeRow)

        let mode = ThemeDefaults.gfxModes.contains(config.gfxMode) ? config.gfxMode : ThemeDefaults.gfxMode
        resolutionPopUp.selectItem(withTitle: mode)

        let hasVolume = volumeManager.selectedVolume != nil
        themePopUp.isEnabled = hasVolume
        resolutionPopUp.isEnabled = hasVolume
        applyButton.isEnabled = hasVolume
        statusLabel.stringValue = hasVolume ? "" : L.t(.selectDevice)
    }

    @objc private func applyTapped() {
        guard let volume = volumeManager.selectedVolume else { return }

        do {
            try ThemeSettingsWriter.apply(
                defaultFileIndex: themePopUp.indexOfSelectedItem,
                gfxMode: resolutionPopUp.titleOfSelectedItem,
                to: volumeManager.themeConfig,
                savingTo: volume.configFileURL
            )
            volumeManager.reloadConfig()
            statusLabel.stringValue = L.t(.settingsSaved)
        } catch {
            AlertHelper.showError(error.localizedDescription, title: L.t(.couldNotUpdateConfig))
        }
    }
}
