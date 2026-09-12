import Foundation

/// What one walk of an installed theme folder turned up.
struct ThemeAssets {
    let themeDescriptor: URL?
    let fontFiles: [URL]
}

/// Filesystem inspection of theme folders, and the path translation Ventoy's
/// config format needs.
enum ThemeFileScanner {
    // MARK: - Scanning

    /// Collects the theme descriptor and every `.pf2` font in a **single**
    /// recursive walk. These used to be two separate full walks of the same
    /// tree for every theme installed.
    static func scanAssets(in directory: URL) -> ThemeAssets {
        var descriptor: URL?
        var fonts: [URL] = []

        enumerate(directory) { url in
            if descriptor == nil, isThemeDescriptor(url) {
                descriptor = url
            } else if url.pathExtension.caseInsensitiveCompare(VentoyPaths.fontExtension) == .orderedSame {
                fonts.append(url)
            }
            return .continue
        }

        return ThemeAssets(themeDescriptor: descriptor, fontFiles: fonts)
    }

    /// Whether a folder holds a theme, used to classify dropped folders.
    /// Stops at the first hit rather than walking the whole tree — this runs
    /// once per candidate subfolder, so on a folder of several large themes
    /// the early exit is the difference between one hit and a full traversal
    /// of every theme's assets.
    static func containsThemeDescriptor(in directory: URL) -> Bool {
        var found = false
        enumerate(directory) { url in
            guard isThemeDescriptor(url) else { return .continue }
            found = true
            return .stop
        }
        return found
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private static func isThemeDescriptor(_ url: URL) -> Bool {
        url.lastPathComponent.caseInsensitiveCompare(VentoyPaths.themeDescriptorName) == .orderedSame
    }

    private enum WalkDecision {
        case `continue`
        case stop
    }

    private static func enumerate(_ directory: URL, _ visit: (URL) -> WalkDecision) {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let url as URL in enumerator {
            if visit(url) == .stop { return }
        }
    }

    // MARK: - Path translation

    /// Converts an absolute path inside `volumeRoot` into the leading-slash,
    /// volume-relative POSIX form Ventoy stores in `ventoy.json`. Returns nil
    /// when the file is not actually inside the volume.
    ///
    /// Compares whole path components rather than raw string prefixes: with
    /// two sticks mounted, plain `hasPrefix` treats "/Volumes/Ventoy 1/x" as
    /// living inside "/Volumes/Ventoy".
    static func relativePosixPath(of fileURL: URL, volumeRoot: URL) -> String? {
        let rootComponents = volumeRoot.standardizedFileURL.pathComponents
        let fileComponents = fileURL.standardizedFileURL.pathComponents

        guard fileComponents.count > rootComponents.count,
              Array(fileComponents.prefix(rootComponents.count)) == rootComponents else { return nil }

        return "/" + fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }

    /// Whether a path recorded in `ventoy.json` points at `folderPath` or
    /// something inside it. Case-insensitive because Ventoy volumes are
    /// exFAT/FAT32, where "/ventoy/theme/Foo" and "/ventoy/theme/foo" are the
    /// same folder.
    static func path(_ recordedPath: String, isWithin folderPath: String) -> Bool {
        let recorded = recordedPath.lowercased()
        let folder = folderPath.lowercased()
        return recorded == folder || recorded.hasPrefix(folder + "/")
    }
}
