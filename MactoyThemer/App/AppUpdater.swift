import AppKit
import Sparkle

/// Owns Sparkle for the application lifetime. Unconfigured development builds
/// remain usable without contacting an invented feed or displaying launch errors.
final class AppUpdater: NSObject, NSMenuItemValidation {
    private var controller: SPUStandardUpdaterController?
    private(set) var startupError: Error?

    static func hasValidConfiguration(_ info: [String: Any]) -> Bool {
        guard let feed = info["SUFeedURL"] as? String,
              let url = URL(string: feed), url.scheme == "https",
              !feed.contains("$("), !url.path.contains("//"),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              let key = info["SUPublicEDKey"] as? String,
              let bytes = Data(base64Encoded: key), bytes.count == 32
        else { return false }
        return true
    }

    func start() {
        guard controller == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              Self.hasValidConfiguration(Bundle.main.infoDictionary ?? [:])
        else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        do {
            try controller.updater.start()
            self.controller = controller
            startupError = nil
        } catch {
            startupError = error
        }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        guard let controller else {
            AlertHelper.showInfo(
                startupError?.localizedDescription
                    ?? L.t(.updatesUnavailableMessage),
                title: L.t(.updatesUnavailableTitle)
            )
            return
        }
        controller.checkForUpdates(sender)
    }

    @objc func toggleAutomaticChecks(_ sender: Any?) {
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleAutomaticChecks(_:)) {
            menuItem.state = controller?.updater.automaticallyChecksForUpdates == true ? .on : .off
            return controller != nil
        }
        return controller?.updater.canCheckForUpdates ?? true
    }
}
