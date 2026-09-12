import Foundation

/// One pending install item: either a theme archive to unpack or a folder to
/// copy as-is. Turning a raw dropped/chosen URL into these is
/// `ThemeSourceClassifier`'s job — this stays a plain value type.
enum ThemeSource: Equatable {
    case archive(URL)
    case themeFolder(URL)

    var url: URL {
        switch self {
        case .archive(let url), .themeFolder(let url):
            return url
        }
    }

    var isFolder: Bool {
        if case .themeFolder = self { return true }
        return false
    }

    /// The folder name this source will be installed under.
    var themeName: String {
        switch self {
        case .archive(let url):
            return ArchiveKind.themeName(forArchive: url)
        case .themeFolder(let url):
            return url.lastPathComponent
        }
    }

    /// Row text for the pending-sources list.
    var displayName: String {
        (isFolder ? "[FOLDER] " : "") + url.lastPathComponent
    }
}

/// Outcome of one Apply run.
struct InstallSummary {
    let processedCount: Int
    let skippedCount: Int
    /// Non-fatal problems — a theme that failed to unpack, or one with no
    /// `theme.txt`. The run continues past each of these.
    let warnings: [String]
}

/// A status line plus a 0…1 fraction, so the progress bar can actually track
/// the run instead of jumping straight from empty to full.
struct InstallProgress {
    let message: String
    let fraction: Double
}
