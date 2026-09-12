import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appUpdater = AppUpdater()
    private var volumeManager: VolumeManager?
    private var windowController: MainWindowController?

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ProcessInfo.processInfo.processName
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        rebuildMainMenu()
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildMainMenu), name: .appLanguageDidChange, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Menu item titles are fixed once created, so a language change rebuilds
    /// the whole bar rather than walking it — it is a handful of objects, and
    /// this also re-points the Language menu's checkmark.
    @objc private func rebuildMainMenu() {
        NSApp.mainMenu = MainMenuBuilder.build(appName: appName, updater: appUpdater)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let volumeManager = VolumeManager()
        let windowController = MainWindowController(volumeManager: volumeManager)
        self.volumeManager = volumeManager
        self.windowController = windowController

        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appUpdater.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Opts into secure coding for restorable state. Without this, AppKit logs
    /// a warning on every launch because it can't assume secure coding is safe
    /// for an app whose deployment target predates macOS 12.
    ///
    /// `@available` is required since the API itself is macOS 12+; older
    /// systems simply never call it, which is the behaviour we want.
    ///
    /// `@objc` is belt-and-braces. Swift does infer it here from the `@objc`
    /// protocol requirement, but AppKit dispatches this by selector, so a
    /// silent loss of the attribute would bring the warning back with no
    /// compile error — `testDelegateExposesSecureRestorableStateToTheObjCRuntime`
    /// is what actually guards that.
    @available(macOS 12.0, *)
    @objc func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
