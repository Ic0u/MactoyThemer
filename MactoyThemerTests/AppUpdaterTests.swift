import XCTest
@testable import MactoyThemer

final class AppUpdaterTests: XCTestCase {
    private let key = Data(repeating: 1, count: 32).base64EncodedString()

    func testUpdateConfigurationRequiresHTTPSAndAValidPublicKey() {
        XCTAssertTrue(AppUpdater.hasValidConfiguration([
            "SUFeedURL": "https://updates.example.com/appcast.xml", "SUPublicEDKey": key
        ]))
        for feed in ["", "http://updates.example.com/appcast.xml", "file:///tmp/appcast.xml",
                     "$(SPARKLE_FEED_URL)", "https://github.com//releases/latest/download/appcast.xml",
                     "https://github.com/$(SPARKLE_GITHUB_REPOSITORY)/releases/latest/download/appcast.xml",
                     "https://user:password@updates.example.com/appcast.xml"] {
            XCTAssertFalse(AppUpdater.hasValidConfiguration(["SUFeedURL": feed, "SUPublicEDKey": key]))
        }
        for invalidKey in ["", "$(SPARKLE_PUBLIC_ED_KEY)", "not-a-key", Data(repeating: 0, count: 31).base64EncodedString()] {
            XCTAssertFalse(AppUpdater.hasValidConfiguration([
                "SUFeedURL": "https://updates.example.com/appcast.xml", "SUPublicEDKey": invalidKey
            ]))
        }
        XCTAssertFalse(AppUpdater.hasValidConfiguration([:]))
    }

    func testApplicationBundleEmbedsSparkleConfiguration() throws {
        let testBundle = Bundle(for: Self.self)
        let appURL = testBundle.bundleURL
            .deletingLastPathComponent() // PlugIns
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // MactoyThemer.app
        let appBundle = try XCTUnwrap(Bundle(url: appURL))
        XCTAssertNotNil(appBundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)
        XCTAssertNotNil(appBundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
    }

    func testUpdateMenuActionsAreConnectedToTheRetainedUpdater() throws {
        let updater = AppUpdater()
        let menu = MainMenuBuilder.build(appName: "MactoyThemer", updater: updater)
        let appMenu = try XCTUnwrap(menu.items.first?.submenu)
        let check = try XCTUnwrap(appMenu.items.first { $0.title == "Check for Updates…" })
        let automatic = try XCTUnwrap(appMenu.items.first { $0.title == "Automatically Check for Updates" })
        XCTAssertTrue(check.target === updater)
        XCTAssertEqual(check.action, #selector(AppUpdater.checkForUpdates(_:)))
        XCTAssertTrue(automatic.target === updater)
        XCTAssertFalse(updater.validateMenuItem(automatic))
        XCTAssertEqual(automatic.state, .off)
    }
}
