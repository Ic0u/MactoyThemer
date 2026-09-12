import AppKit

/// The languages the interface ships with. Adding another means adding a case
/// here and a column in `Strings.table` — nothing else in the app changes.
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case japanese = "ja"
    case russian = "ru"
    case vietnamese = "vi"
    case chinese = "zh-Hans"

    /// Shown in the Language menu, always written in that language itself —
    /// someone looking for their own language shouldn't have to read English
    /// to find it.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .french: return "Français"
        case .japanese: return "日本語"
        case .russian: return "Русский"
        case .vietnamese: return "Tiếng Việt"
        case .chinese: return "简体中文"
        }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("AppLanguageDidChange")
}

/// Holds the chosen interface language and tells the UI when it changes.
///
/// Deliberately not `NSLocalizedString`/`.lproj`: those resolve once at launch
/// from the system language, so switching would mean relaunching the app. A
/// small in-process table lets the Language menu take effect immediately.
final class LocalizationManager: NSObject {
    static let shared = LocalizationManager()

    private static let defaultsKey = "MactoyThemerLanguage"

    /// Tests flip languages constantly; without this they would overwrite the
    /// language the user actually picked, and an interrupted run would leave
    /// the app started up in whichever language the suite stopped on.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var current: AppLanguage {
        didSet {
            guard current != oldValue else { return }
            if !Self.isRunningTests {
                UserDefaults.standard.set(current.rawValue, forKey: Self.defaultsKey)
            }
            NotificationCenter.default.post(name: .appLanguageDidChange, object: self)
        }
    }

    private override init() {
        if let saved = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let language = AppLanguage(rawValue: saved) {
            current = language
        } else {
            current = Self.systemDefault()
        }
        super.init()
    }

    /// First launch follows the Mac's own language when we have that
    /// translation, and falls back to English otherwise.
    private static func systemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return AppLanguage.allCases.first { preferred.hasPrefix($0.rawValue.prefix(2)) } ?? .english
    }

    func select(_ language: AppLanguage) {
        current = language
    }

    /// Target for the Language menu items; the language rides along on the
    /// item's `representedObject`.
    @objc func selectLanguageFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = AppLanguage(rawValue: raw) else { return }
        select(language)
    }
}
