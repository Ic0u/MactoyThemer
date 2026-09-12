import Foundation

enum ThemeConfigError: LocalizedError {
    case notAJSONObject

    var errorDescription: String? {
        switch self {
        case .notAJSONObject:
            return "ventoy.json is not a valid JSON object."
        }
    }
}


final class ThemeConfig {
    private enum Key {
        static let theme = "theme"
        static let file = "file"
        static let fonts = "fonts"
        static let images = "images"
        static let defaultFile = "default_file"
        static let gfxMode = "gfxmode"
        static let displayMode = "display_mode"
        static let serialParam = "serial_param"
    }

    private var root: [String: Any]
    private var theme: [String: Any]

    init(root: [String: Any] = [:]) {
        var remainder = root
        self.theme = remainder.removeValue(forKey: Key.theme) as? [String: Any] ?? [:]
        self.root = remainder
    }

    static func loadIfPresent(at url: URL) throws -> ThemeConfig {
        guard FileManager.default.fileExists(atPath: url.path) else { return ThemeConfig() }
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ThemeConfigError.notAJSONObject
        }
        return ThemeConfig(root: object)
    }

    // MARK: - The `theme` object

    var themeFiles: [String] {
        get { theme[Key.file] as? [String] ?? [] }
        set { theme[Key.file] = newValue }
    }

    var fontFiles: [String] {
        get { theme[Key.fonts] as? [String] ?? [] }
        set { theme[Key.fonts] = newValue }
    }

    var imageFiles: [String] {
        get { theme[Key.images] as? [String] ?? [] }
        set { theme[Key.images] = newValue }
    }

    var defaultFileIndex: Int {
        get { theme[Key.defaultFile] as? Int ?? 0 }
        set { theme[Key.defaultFile] = newValue }
    }

    var gfxMode: String {
        get { theme[Key.gfxMode] as? String ?? ThemeDefaults.gfxMode }
        set { theme[Key.gfxMode] = newValue }
    }

    var installedThemeNames: [String] {
        themeFiles.map { URL(fileURLWithPath: $0).deletingLastPathComponent().lastPathComponent }
    }

    var defaultThemeRow: Int {
        let index = defaultFileIndex
        return (index >= 1 && index <= themeFiles.count) ? index : 0
    }


    func save(to url: URL) throws {
        var output = root
        output[Key.theme] = themeWithDefaults()

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func themeWithDefaults() -> [String: Any] {
        var result = theme
        let defaults: [String: Any] = [
            Key.file: [String](),
            Key.fonts: [String](),
            Key.images: [String](),
            Key.defaultFile: 0,
            Key.gfxMode: ThemeDefaults.gfxMode,
            Key.displayMode: ThemeDefaults.displayMode,
            Key.serialParam: ThemeDefaults.serialParam
        ]
        for (key, value) in defaults where result[key] == nil {
            result[key] = value
        }
        return result
    }
}
