import AppKit

extension Notification.Name {
    /// Posted whenever the mounted volume list, the selection, or the loaded
    /// config changes. Every tab observes this and re-reads what it needs;
    /// no tab ever talks to another directly.
    static let volumeManagerDidChange = Notification.Name("VolumeManagerDidChange")
}

/// The single source of truth for "which Ventoy drive are we editing, and
/// what does its config say". Created once by `AppDelegate` and injected by
/// reference into every view controller.
final class VolumeManager {
    private(set) var scannedVolumes: [VentoyVolume] = []

    /// Folders the user pointed at by hand via Choose…, kept across rescans
    /// so a manually picked drive doesn't vanish when the list refreshes.
    private(set) var manualVolumes: [VentoyVolume] = []

    private(set) var selectedVolume: VentoyVolume?
    private(set) var themeConfig = ThemeConfig()

    /// Theme folder names on disk, recomputed lazily. The Remove tab asks for
    /// these on every change notification, which would otherwise mean a
    /// directory listing per notification.
    private var themeFolderNamesCache: [String]?

    var volumes: [VentoyVolume] { scannedVolumes + manualVolumes }

    init() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name: NSNotification.Name in [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ] {
            workspaceCenter.addObserver(self, selector: #selector(rescanVolumes), name: name, object: nil)
        }
        rescanVolumes()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Volume list

    /// Notifies only when the mounted set or the selection actually changed.
    /// This fires on every mount/unmount and every time the device popup
    /// opens; notifying unconditionally re-parsed `ventoy.json` on each of
    /// those and rebuilt the very menu that was in the middle of opening.
    @objc func rescanVolumes() {
        let scanned = VolumeScanner.scanMountedVolumes()
        let selectionStillAvailable = selectedVolume.map { scanned.contains($0) || manualVolumes.contains($0) } ?? false

        guard scanned != scannedVolumes || !selectionStillAvailable else { return }
        scannedVolumes = scanned

        if selectionStillAvailable {
            notifyChanged()
        } else {
            apply(selection: scanned.first ?? manualVolumes.first)
        }
    }

    func select(_ volume: VentoyVolume?) {
        guard volume != selectedVolume else { return }
        apply(selection: volume)
    }

    /// Adds and selects an arbitrary folder as the active volume — for a
    /// renamed Ventoy drive the `/Volumes` name scan won't flag.
    func selectManualLocation(_ url: URL) {
        let volume = VentoyVolume(name: url.lastPathComponent, mountURL: url, isAutoDetected: false)
        if !volumes.contains(volume) {
            manualVolumes.append(volume)
        }
        apply(selection: volume)
    }

    private func apply(selection volume: VentoyVolume?) {
        selectedVolume = volume
        reloadConfig()
    }

    // MARK: - Config

    func reloadConfig() {
        themeFolderNamesCache = nil

        guard let volume = selectedVolume else {
            themeConfig = ThemeConfig()
            notifyChanged()
            return
        }

        do {
            themeConfig = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        } catch {
            themeConfig = ThemeConfig()
            AlertHelper.showError("Could not read ventoy.json on \(volume.name): \(error.localizedDescription)")
        }
        notifyChanged()
    }

    /// Theme folders actually present under `ventoy/theme/`. The Remove tab
    /// lists disk truth rather than JSON truth, since a folder can outlive
    /// (or never have had) a matching config entry.
    func installedThemeFolderNames() -> [String] {
        if let cached = themeFolderNamesCache { return cached }

        guard let volume = selectedVolume,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: volume.themesDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
        else {
            themeFolderNamesCache = []
            return []
        }

        let names = contents
            .filter { ThemeFileScanner.isDirectory($0) }
            .map { $0.lastPathComponent }
            .sorted()
        themeFolderNamesCache = names
        return names
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .volumeManagerDidChange, object: self)
    }
}
