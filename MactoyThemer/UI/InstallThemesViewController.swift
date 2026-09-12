import AppKit


final class InstallThemesViewController: VolumeAwareViewController {
    private var pendingSources: [ThemeSource] = []
    private var stagedURLs = Set<URL>()
    private var isInstalling = false

    private let tableView = DropTableView()
    private let emptyState = ThemeDropEmptyState()
    private let addButton = NSButton(title: "", target: nil, action: nil)
    private let clearButton = NSButton(title: "", target: nil, action: nil)
    private let applyButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressBar = NSProgressIndicator()
    private lazy var progressHeight = progressBar.heightAnchor.constraint(equalToConstant: 0)

    override func buildLayout() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 12, height: 4)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.onDrop = { [weak self] urls in self?.stage(urls) }
        tableView.onDeleteKey = { [weak self] in self?.removeSelectedRows() }
        scrollView.documentView = tableView
        emptyState.translatesAutoresizingMaskIntoConstraints = false

        for button in [addButton, clearButton, applyButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.target = self
        }
        InterfaceStyle.iconOnly(addButton, symbol: "plus", fallback: NSImage.addTemplateName, accessibilityLabel: L.t(.addThemes))
        InterfaceStyle.iconOnly(clearButton, symbol: "minus", fallback: NSImage.removeTemplateName, accessibilityLabel: L.t(.clear))
        addButton.action = #selector(addTapped)
        clearButton.action = #selector(clearTapped)
        applyButton.action = #selector(applyTapped)
        applyButton.keyEquivalent = "\r"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.alignment = .right
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // The progress strip collapses completely while idle.
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.isHidden = true

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let toolbar = NSStackView(views: [addButton, clearButton, spacer, statusLabel, applyButton])
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 10

        for subview in [scrollView, emptyState, progressBar, toolbar] {
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: progressBar.topAnchor),
            emptyState.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            emptyState.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyState.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            progressBar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            progressHeight,
            progressBar.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -8),

            toolbar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 28),
            clearButton.widthAnchor.constraint(equalToConstant: 28),
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 8),
            applyButton.widthAnchor.constraint(equalToConstant: 90)
        ])
    }

    override func applyLocalizedStrings() {
        applyButton.title = L.t(.install)
        tableView.tableColumns.first?.title = L.t(.themesToInstall)
        tableView.setAccessibilityLabel(L.t(.dropListAccessibility))
        InterfaceStyle.iconOnly(addButton, symbol: "plus", fallback: NSImage.addTemplateName,
                                accessibilityLabel: L.t(.addThemes))
        InterfaceStyle.iconOnly(clearButton, symbol: "minus", fallback: NSImage.removeTemplateName,
                                accessibilityLabel: L.t(.clear))
        clearButton.toolTip = L.t(.clearTooltip)
    }

    override func volumeStateDidChange() {
        updateControlState()
    }

    // MARK: - Staging

    @objc private func addTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        // Only gates files — folders stay selectable, which is exactly the
        // "an archive or any theme folder" behaviour this tab wants.
        panel.allowedFileTypes = ArchiveKind.openPanelExtensions
        panel.message = L.t(.choosePanelMessage)

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.stage(panel.urls)
        }
    }

    private func stage(_ urls: [URL]) {
        let added = ThemeSourceClassifier.classify(urls, excluding: stagedURLs)
        for source in added {
            stagedURLs.insert(source.url)
        }
        pendingSources.append(contentsOf: added)

        tableView.reloadData()
        updateControlState()
        statusLabel.stringValue = added.isEmpty
            ? L.t(.noSupportedThemes)
            : L.t(.addedItems, added.count)
    }

    private func removeSelectedRows() {
        guard !isInstalling else { return }
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        for index in selected.sorted(by: >) {
            stagedURLs.remove(pendingSources[index].url)
            pendingSources.remove(at: index)
        }
        tableView.reloadData()
        updateControlState()
    }

    @objc private func clearTapped() {
        pendingSources.removeAll()
        stagedURLs.removeAll()
        tableView.reloadData()
        updateControlState()
        resetStatus()
    }

    // MARK: - Install

    @objc private func applyTapped() {
        guard let volume = volumeManager.selectedVolume, !pendingSources.isEmpty else { return }

        isInstalling = true
        updateControlState()
        progressBar.doubleValue = 0
        statusLabel.stringValue = L.t(.starting)

        // Every callback below already arrives on the main queue — the
        // installer owns that hop so this stays plain UI code.
        ThemeInstaller.install(
            sources: pendingSources,
            into: volume,
            progress: { [weak self] update in
                self?.statusLabel.stringValue = update.message
                self?.progressBar.doubleValue = update.fraction
            },
            confirmOverwrite: { name in
                AlertHelper.confirm(
                    title: L.t(.confirmOverwriteTitle),
                    message: L.t(.confirmOverwriteMessage, name),
                    confirmTitle: L.t(.overwrite)
                )
            },
            completion: { [weak self] result in
                self?.finishInstall(result)
            }
        )
    }

    private func finishInstall(_ result: Result<InstallSummary, Error>) {
        isInstalling = false
        progressBar.doubleValue = 1

        switch result {
        case .failure(let error):
            statusLabel.stringValue = L.t(.installFailed)
            updateControlState()
            AlertHelper.showError(error.localizedDescription, title: L.t(.couldNotUpdateConfig))

        case .success(let summary):
            if summary.processedCount > 0 {
                pendingSources.removeAll()
                stagedURLs.removeAll()
                tableView.reloadData()
                // Refreshes the Settings and Remove tabs too.
                volumeManager.reloadConfig()
            }
            updateControlState()
            statusLabel.stringValue = summaryText(for: summary)

            if !summary.warnings.isEmpty {
                AlertHelper.showInfo(
                    summary.warnings.joined(separator: "\n\n"),
                    title: L.t(.themesHadIssues)
                )
            }
        }
    }

    private func summaryText(for summary: InstallSummary) -> String {
        guard summary.processedCount > 0 else {
            return summary.skippedCount > 0 ? L.t(.allSkipped) : L.t(.nothingInstalled)
        }
        var text = L.t(.installedCount, summary.processedCount)
        if summary.skippedCount > 0 {
            text += L.t(.skippedCount, summary.skippedCount)
        }
        return text
    }

    // MARK: - Control state

    private func updateControlState() {
        let idle = !isInstalling
        addButton.isEnabled = idle
        clearButton.isEnabled = idle && !pendingSources.isEmpty
        applyButton.isEnabled = idle && !pendingSources.isEmpty && volumeManager.selectedVolume != nil
        tableView.isEnabled = idle
        tableView.acceptsDrops = idle
        emptyState.isHidden = !pendingSources.isEmpty
        progressBar.isHidden = idle
        progressHeight.constant = idle ? 0 : 4
        if idle && pendingSources.isEmpty { resetStatus() }
    }

    private func resetStatus() {
        statusLabel.stringValue = volumeManager.selectedVolume == nil
            ? L.t(.selectDeviceToApply)
            : L.t(.ready)
        progressBar.doubleValue = 0
    }
}

// MARK: - Pending sources list

extension InstallThemesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        pendingSources.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SourceCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier
                let image = NSImageView()
                let label = NSTextField(labelWithString: "")
                label.lineBreakMode = .byTruncatingMiddle
                for child in [image, label] {
                    child.translatesAutoresizingMaskIntoConstraints = false
                    cell.addSubview(child)
                }
                cell.imageView = image
                cell.textField = label
                NSLayoutConstraint.activate([
                    image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                    image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    image.widthAnchor.constraint(equalToConstant: 20),
                    image.heightAnchor.constraint(equalToConstant: 20),
                    label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
                    label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                return cell
            }()
        let source = pendingSources[row]
        cell.textField?.stringValue = source.displayName
        cell.toolTip = source.url.path
        switch source {
        case .archive:
            cell.imageView?.image = InterfaceStyle.icon("doc.zipper", fallback: NSImage.multipleDocumentsName)
        case .themeFolder:
            cell.imageView?.image = InterfaceStyle.icon("folder", fallback: NSImage.folderName)
        }
        return cell
    }
}
