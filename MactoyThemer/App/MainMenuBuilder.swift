import AppKit

/// With no storyboard or xib there is no menu bar unless one is built here —
/// including the Edit menu, without which Cmd-X/C/V do nothing in any text
/// field in the app, and the Window menu, without which Cmd-M does nothing.
///
/// Every title is looked up at build time, so switching language just means
/// rebuilding the menu (see `AppDelegate`).
enum MainMenuBuilder {
    static func build(appName: String, updater: AppUpdater? = nil) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenu(titled: appName, items: appMenuItems(appName: appName, updater: updater)))
        mainMenu.addItem(submenu(titled: L.t(.menuEdit), items: editMenuItems()))
        mainMenu.addItem(submenu(titled: L.t(.menuLanguage), items: languageMenuItems()))
        mainMenu.addItem(submenu(titled: L.t(.menuWindow), items: windowMenuItems()))
        return mainMenu
    }

    private static func appMenuItems(appName: String, updater: AppUpdater?) -> [NSMenuItem] {
        let check = item(L.t(.menuCheckUpdates), #selector(AppUpdater.checkForUpdates(_:)))
        check.target = updater
        let automatic = item(L.t(.menuAutoCheckUpdates), #selector(AppUpdater.toggleAutomaticChecks(_:)))
        automatic.target = updater
        return [
            item(L.t(.menuAbout, appName), #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            check,
            automatic,
            .separator(),
            item(L.t(.menuHide, appName), #selector(NSApplication.hide(_:)), "h"),
            item(L.t(.menuHideOthers), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item(L.t(.menuShowAll), #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item(L.t(.menuQuit, appName), #selector(NSApplication.terminate(_:)), "q")
        ]
    }

    private static func editMenuItems() -> [NSMenuItem] {
        [
            // Undo/redo are dispatched by name: NSUndoManager's selectors
            // aren't exposed to Swift as `#selector`-able methods.
            item(L.t(.menuUndo), Selector(("undo:")), "z"),
            item(L.t(.menuRedo), Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item(L.t(.menuCut), #selector(NSText.cut(_:)), "x"),
            item(L.t(.menuCopy), #selector(NSText.copy(_:)), "c"),
            item(L.t(.menuPaste), #selector(NSText.paste(_:)), "v"),
            item(L.t(.menuSelectAll), #selector(NSText.selectAll(_:)), "a")
        ]
    }

    /// One item per shipped language, checkmarked on the active one. Titles
    /// stay in their own language rather than being translated, so the list
    /// reads the same whichever language is currently selected.
    private static func languageMenuItems() -> [NSMenuItem] {
        let manager = LocalizationManager.shared
        return AppLanguage.allCases.map { language in
            let entry = NSMenuItem(
                title: language.displayName,
                action: #selector(LocalizationManager.selectLanguageFromMenu(_:)),
                keyEquivalent: ""
            )
            entry.target = manager
            entry.representedObject = language.rawValue
            entry.state = (language == manager.current) ? .on : .off
            return entry
        }
    }

    private static func windowMenuItems() -> [NSMenuItem] {
        [
            item(L.t(.menuMinimize), #selector(NSWindow.performMiniaturize(_:)), "m"),
            item(L.t(.menuZoom), #selector(NSWindow.performZoom(_:))),
            .separator(),
            item(L.t(.menuClose), #selector(NSWindow.performClose(_:)), "w")
        ]
    }

    // MARK: - Construction helpers

    private static func submenu(titled title: String, items: [NSMenuItem]) -> NSMenuItem {
        let container = NSMenuItem()
        let menu = NSMenu(title: title)
        for item in items {
            menu.addItem(item)
        }
        container.submenu = menu
        return container
    }

    private static func item(
        _ title: String,
        _ action: Selector,
        _ keyEquivalent: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        return item
    }
}
