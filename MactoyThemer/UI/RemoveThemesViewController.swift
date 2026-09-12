import AppKit

/// Tab 3: delete installed themes from the drive and prune them out of
/// `ventoy.json`.
final class RemoveThemesViewController: VolumeAwareViewController {
    /// Computed, not stored: it is inserted into the popup and later compared
    /// against the selection, so both sides must read the same live translation.
    private static var placeholderTitle: String { L.t(.selectThemeToDelete) }

    private let label = NSTextField(labelWithString: "")
    private let themePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let removeButton = NSButton(title: "", target: nil, action: nil)
    private let removeAllButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    private var isWorking = false

    override func buildLayout() {
        label.font = .systemFont(ofSize: 12, weight: .medium)
        themePopUp.target = self
        themePopUp.action = #selector(selectionChanged)
        InterfaceStyle.iconOnly(removeButton, symbol: "trash", fallback: NSImage.trashEmptyName,
                                accessibilityLabel: L.t(.removeSelectedAccessibility))
        InterfaceStyle.iconOnly(removeAllButton, symbol: "trash.slash", fallback: NSImage.trashFullName,
                                accessibilityLabel: L.t(.removeAllAccessibility))
        for subview in [label, themePopUp, removeAllButton, removeButton, statusLabel, spinner] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        for button in [removeAllButton, removeButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        removeButton.action = #selector(removeSelectedTapped)
        removeAllButton.action = #selector(removeAllTapped)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.lineBreakMode = .byTruncatingTail

        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        spinner.controlSize = .small

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            themePopUp.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            themePopUp.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            themePopUp.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: spinner.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor),

            spinner.trailingAnchor.constraint(equalTo: removeAllButton.leadingAnchor, constant: -12),
            spinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),

            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),
            removeAllButton.widthAnchor.constraint(equalToConstant: 28),
            removeAllButton.centerYAnchor.constraint(equalTo: removeButton.centerYAnchor),
            removeAllButton.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),
            removeButton.widthAnchor.constraint(equalToConstant: 28),
            removeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            removeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    override func applyLocalizedStrings() {
        label.stringValue = L.t(.installedTheme)
        themePopUp.setAccessibilityLabel(L.t(.installedTheme))
        InterfaceStyle.iconOnly(removeButton, symbol: "trash", fallback: NSImage.trashEmptyName,
                                accessibilityLabel: L.t(.removeSelectedAccessibility))
        InterfaceStyle.iconOnly(removeAllButton, symbol: "trash.slash", fallback: NSImage.trashFullName,
                                accessibilityLabel: L.t(.removeAllAccessibility))
    }

    override func volumeStateDidChange() {
        let names = volumeManager.installedThemeFolderNames()
        let previousSelection = themePopUp.titleOfSelectedItem

        themePopUp.removeAllItems()
        themePopUp.addItem(withTitle: Self.placeholderTitle)
        themePopUp.addItems(withTitles: names)
        if let previousSelection, names.contains(previousSelection) {
            themePopUp.selectItem(withTitle: previousSelection)
        }

        updateControlState(installedCount: names.count)
    }

    @objc private func selectionChanged() {
        updateControlState(installedCount: volumeManager.installedThemeFolderNames().count)
    }

    // MARK: - Actions

    @objc private func removeSelectedTapped() {
        guard let volume = volumeManager.selectedVolume else { return }
        guard let name = themePopUp.titleOfSelectedItem, name != Self.placeholderTitle else {
            AlertHelper.showInfo(L.t(.chooseThemeFirst), title: L.t(.noThemeSelectedTitle))
            return
        }
        guard AlertHelper.confirm(
            title: L.t(.deleteThemeTitle, name),
            message: L.t(.deleteThemeMessage)
        ) else { return }

        beginWork(status: L.t(.deletingTheme, name))
        ThemeRemover.removeTheme(named: name, from: volume) { [weak self] result in
            self?.finish(result, successMessage: L.t(.deletedTheme, name))
        }
    }

    @objc private func removeAllTapped() {
        guard let volume = volumeManager.selectedVolume else { return }
        let names = volumeManager.installedThemeFolderNames()
        guard !names.isEmpty else { return }

        guard AlertHelper.confirm(
            title: L.t(.deleteAllTitle, names.count),
            message: L.t(.deleteAllMessage)
        ) else { return }

        beginWork(status: L.t(.deletingAllThemes))
        ThemeRemover.removeAllThemes(from: volume) { [weak self] result in
            self?.finish(result, successMessage: L.t(.removedAllThemes))
        }
    }

    private func finish(_ result: Result<Void, Error>, successMessage: String) {
        isWorking = false
        spinner.stopAnimation(nil)

        switch result {
        case .success:
            statusLabel.stringValue = successMessage
            // Refreshes this tab's list and the other tabs.
            volumeManager.reloadConfig()
        case .failure(let error):
            statusLabel.stringValue = L.t(.deleteFailed)
            updateControlState(installedCount: volumeManager.installedThemeFolderNames().count)
            AlertHelper.showError(error.localizedDescription, title: L.t(.couldNotRemoveTheme))
        }
    }

    // MARK: - Control state

    private func beginWork(status: String) {
        isWorking = true
        statusLabel.stringValue = status
        spinner.startAnimation(nil)
        updateControlState(installedCount: volumeManager.installedThemeFolderNames().count)
    }

    private func updateControlState(installedCount: Int) {
        let canRemove = !isWorking && volumeManager.selectedVolume != nil && installedCount > 0
        removeButton.isEnabled = canRemove && themePopUp.indexOfSelectedItem > 0
        removeAllButton.isEnabled = canRemove
        themePopUp.isEnabled = !isWorking && installedCount > 0

        guard !isWorking else { return }
        if volumeManager.selectedVolume == nil {
            statusLabel.stringValue = L.t(.selectDeviceToManage)
        } else if installedCount == 0 {
            statusLabel.stringValue = L.t(.noThemesInstalled)
        }
    }
}
