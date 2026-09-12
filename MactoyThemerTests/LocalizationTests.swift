import AppKit
import XCTest
@testable import MactoyThemer

final class LocalizationTests: XCTestCase {
    private var original: AppLanguage!

    override func setUpWithError() throws {
        original = LocalizationManager.shared.current
    }

    override func tearDownWithError() throws {
        LocalizationManager.shared.select(original)
    }

    func testEveryKeyHasATranslationInEveryShippedLanguage() {
        // A missing entry falls back to English silently, so only a test can
        // catch a language that was added but never filled in.
        var missing: [String] = []
        for key in LocalizationTests.allKeys {
            for language in AppLanguage.allCases {
                LocalizationManager.shared.select(language)
                let value = L.t(key.0)
                if value.isEmpty {
                    missing.append("\(key.1) [\(language.rawValue)]")
                }
            }
        }
        XCTAssertEqual(missing, [], "keys with no usable string")
    }

    func testTranslationsActuallyDifferPerLanguage() {
        LocalizationManager.shared.select(.english)
        let english = L.t(.tabInstall)
        LocalizationManager.shared.select(.vietnamese)
        let vietnamese = L.t(.tabInstall)
        LocalizationManager.shared.select(.chinese)
        let chinese = L.t(.tabInstall)

        XCTAssertEqual(english, "Install")
        XCTAssertNotEqual(vietnamese, english)
        XCTAssertNotEqual(chinese, english)
    }

    func testFormattingSubstitutesArguments() {
        LocalizationManager.shared.select(.english)
        XCTAssertEqual(L.t(.deleteThemeTitle, "Slate"), "Delete 'Slate'?")
        XCTAssertEqual(L.t(.installedCount, 3), "Installed 3 theme(s).")
    }

    func testSelectingALanguageNotifiesObservers() {
        LocalizationManager.shared.select(.english)
        let notified = expectation(description: "language change posted")
        let token = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { _ in notified.fulfill() }
        defer { NotificationCenter.default.removeObserver(token) }

        LocalizationManager.shared.select(.vietnamese)
        wait(for: [notified], timeout: 5)
    }

    func testSelectingTheSameLanguageDoesNotNotify() {
        LocalizationManager.shared.select(.english)
        var fired = false
        let token = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange, object: nil, queue: .main
        ) { _ in fired = true }
        defer { NotificationCenter.default.removeObserver(token) }

        LocalizationManager.shared.select(.english)
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(fired, "re-selecting the active language should be a no-op")
    }

    // MARK: - Menu

    func testMenuBarExposesALanguageMenuWithEveryLanguage() throws {
        LocalizationManager.shared.select(.english)
        let menu = MainMenuBuilder.build(appName: "MactoyThemer")
        let language = try XCTUnwrap(menu.items.first { $0.submenu?.title == "Language" }?.submenu)

        XCTAssertEqual(language.items.map(\.title), AppLanguage.allCases.map(\.displayName))
        XCTAssertEqual(language.items.filter { $0.state == .on }.map(\.title), ["English"])
    }

    func testLanguageMenuItemSwitchesTheLanguage() throws {
        LocalizationManager.shared.select(.english)
        let menu = MainMenuBuilder.build(appName: "MactoyThemer")
        let language = try XCTUnwrap(menu.items.first { $0.submenu?.title == "Language" }?.submenu)
        let vietnamese = try XCTUnwrap(language.items.first { $0.title == "Tiếng Việt" })

        LocalizationManager.shared.selectLanguageFromMenu(vietnamese)

        XCTAssertEqual(LocalizationManager.shared.current, .vietnamese)
    }

    /// The menu is rebuilt on language change, so its titles must follow.
    func testRebuiltMenuIsTranslated() throws {
        LocalizationManager.shared.select(.vietnamese)
        let menu = MainMenuBuilder.build(appName: "MactoyThemer")
        XCTAssertNotNil(menu.items.first { $0.submenu?.title == "Ngôn ngữ" })
        XCTAssertNotNil(menu.items.first { $0.submenu?.title == "Chỉnh sửa" })
    }

    /// Every key, paired with its name, so a failure says which one broke.
    private static let allKeys: [(L.Key, String)] = [
        (.menuAbout, "menuAbout"), (.menuCheckUpdates, "menuCheckUpdates"),
        (.menuAutoCheckUpdates, "menuAutoCheckUpdates"), (.menuHide, "menuHide"),
        (.menuHideOthers, "menuHideOthers"), (.menuShowAll, "menuShowAll"),
        (.menuQuit, "menuQuit"), (.menuEdit, "menuEdit"), (.menuUndo, "menuUndo"),
        (.menuRedo, "menuRedo"), (.menuCut, "menuCut"), (.menuCopy, "menuCopy"),
        (.menuPaste, "menuPaste"), (.menuSelectAll, "menuSelectAll"),
        (.menuWindow, "menuWindow"), (.menuMinimize, "menuMinimize"),
        (.menuZoom, "menuZoom"), (.menuClose, "menuClose"), (.menuLanguage, "menuLanguage"),
        (.tabInstall, "tabInstall"), (.tabSettings, "tabSettings"), (.tabRemove, "tabRemove"),
        (.deviceLabel, "deviceLabel"), (.deviceAccessibility, "deviceAccessibility"),
        (.browse, "browse"), (.browseTooltip, "browseTooltip"),
        (.noDeviceFound, "noDeviceFound"), (.notDetectedSuffix, "notDetectedSuffix"),
        (.choosePrompt, "choosePrompt"), (.chooseMessage, "chooseMessage"),
        (.themesToInstall, "themesToInstall"), (.dropListAccessibility, "dropListAccessibility"),
        (.addThemes, "addThemes"), (.clear, "clear"), (.clearTooltip, "clearTooltip"),
        (.install, "install"), (.ready, "ready"), (.selectDeviceToApply, "selectDeviceToApply"),
        (.choosePanelMessage, "choosePanelMessage"), (.noSupportedThemes, "noSupportedThemes"),
        (.addedItems, "addedItems"), (.starting, "starting"), (.installFailed, "installFailed"),
        (.couldNotUpdateConfig, "couldNotUpdateConfig"),
        (.confirmOverwriteTitle, "confirmOverwriteTitle"),
        (.confirmOverwriteMessage, "confirmOverwriteMessage"), (.overwrite, "overwrite"),
        (.themesHadIssues, "themesHadIssues"), (.nothingInstalled, "nothingInstalled"),
        (.allSkipped, "allSkipped"), (.installedCount, "installedCount"),
        (.skippedCount, "skippedCount"), (.dropThemesHere, "dropThemesHere"),
        (.archivesOrFolders, "archivesOrFolders"), (.defaultTheme, "defaultTheme"),
        (.displayResolution, "displayResolution"), (.saveSettings, "saveSettings"),
        (.randomTheme, "randomTheme"), (.selectDevice, "selectDevice"),
        (.settingsSaved, "settingsSaved"), (.installedTheme, "installedTheme"),
        (.selectThemeToDelete, "selectThemeToDelete"),
        (.removeSelectedAccessibility, "removeSelectedAccessibility"),
        (.removeAllAccessibility, "removeAllAccessibility"),
        (.selectDeviceToManage, "selectDeviceToManage"),
        (.noThemesInstalled, "noThemesInstalled"),
        (.noThemeSelectedTitle, "noThemeSelectedTitle"), (.chooseThemeFirst, "chooseThemeFirst"),
        (.deleteThemeTitle, "deleteThemeTitle"), (.deleteThemeMessage, "deleteThemeMessage"),
        (.deleteAllTitle, "deleteAllTitle"), (.deleteAllMessage, "deleteAllMessage"),
        (.deletedTheme, "deletedTheme"), (.removedAllThemes, "removedAllThemes"),
        (.deletingTheme, "deletingTheme"), (.deletingAllThemes, "deletingAllThemes"),
        (.deleteFailed, "deleteFailed"), (.couldNotRemoveTheme, "couldNotRemoveTheme"),
        (.cancel, "cancel"), (.delete, "delete"),
        (.updatesUnavailableTitle, "updatesUnavailableTitle"),
        (.updatesUnavailableMessage, "updatesUnavailableMessage")
    ]
}
