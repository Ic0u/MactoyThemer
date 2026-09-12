import AppKit

/// A single device selection shared by three focused workspaces.
final class RootViewController: VolumeAwareViewController {
    private lazy var drivePicker = DrivePickerView(volumeManager: volumeManager)
    private let tabViewController = NSTabViewController()
    private let navigation = NSSegmentedControl()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 360))
    }

    override func buildLayout() {
        tabViewController.tabStyle = .unspecified
        tabViewController.tabView.tabViewType = .noTabsNoBorder

        let tabs: [(String, String, NSImage.Name, NSViewController)] = [
            (L.t(.tabInstall), "square.and.arrow.down", NSImage.followLinkFreestandingTemplateName,
             InstallThemesViewController(volumeManager: volumeManager)),
            (L.t(.tabSettings), "slider.horizontal.3", NSImage.actionTemplateName,
             ThemeSettingsViewController(volumeManager: volumeManager)),
            (L.t(.tabRemove), "trash", NSImage.trashEmptyName,
             RemoveThemesViewController(volumeManager: volumeManager))
        ]
        navigation.segmentCount = tabs.count
        navigation.segmentStyle = .rounded
        navigation.trackingMode = .selectOne
        navigation.target = self
        navigation.action = #selector(tabChanged)
        navigation.translatesAutoresizingMaskIntoConstraints = false
        for (index, tab) in tabs.enumerated() {
            let item = NSTabViewItem(viewController: tab.3)
            item.label = tab.0
            tabViewController.addTabViewItem(item)
            navigation.setLabel(tab.0, forSegment: index)
            navigation.setImage(InterfaceStyle.icon(tab.1, fallback: tab.2), forSegment: index)
            navigation.setImageScaling(.scaleProportionallyDown, forSegment: index)
            // No forced per-segment width: letting each segment size to its
            // own label+icon is what keeps "Install/Settings/Remove" from
            // sitting in three identically bloated boxes.
        }
        navigation.selectedSegment = 0
        navigation.setAccessibilityLabel("Theme workspace")

        addChild(tabViewController)
        let content = tabViewController.view
        content.translatesAutoresizingMaskIntoConstraints = false
        let divider = InterfaceStyle.separator()
        for child in [drivePicker, navigation, divider, content] { view.addSubview(child) }
        NSLayoutConstraint.activate([
            drivePicker.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            drivePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            drivePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            navigation.topAnchor.constraint(equalTo: drivePicker.bottomAnchor, constant: 8),
            navigation.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            divider.topAnchor.constraint(equalTo: navigation.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }

    override func applyLocalizedStrings() {
        let titles = [L.t(.tabInstall), L.t(.tabSettings), L.t(.tabRemove)]
        for (index, title) in titles.enumerated() where index < navigation.segmentCount {
            navigation.setLabel(title, forSegment: index)
            tabViewController.tabViewItems[index].label = title
        }
    }

    @objc private func tabChanged() {
        tabViewController.selectedTabViewItemIndex = navigation.selectedSegment
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let content = tabViewController.view
        content.alphaValue = 0.65
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            content.animator().alphaValue = 1
        }
    }
}
