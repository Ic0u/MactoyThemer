import Foundation


enum ArchiveKind {
    case zipFamily
    case tarFamily


    private static let recognizedSuffixes: [(suffix: String, kind: ArchiveKind)] = [
        (".tar.gz", .tarFamily), (".tar.bz2", .tarFamily), (".tar.xz", .tarFamily),
        (".tar.zst", .tarFamily), (".tgz", .tarFamily), (".tar", .tarFamily),
        (".zipx", .zipFamily), (".zip", .zipFamily)
    ]


    static let openPanelExtensions = ["zip", "zipx", "tar", "tgz", "gz", "bz2", "xz", "zst"]

    private static func matchedSuffix(for url: URL) -> (suffix: String, kind: ArchiveKind)? {
        let name = url.lastPathComponent.lowercased()
        return recognizedSuffixes.first { name.hasSuffix($0.suffix) }
    }

    static func of(_ url: URL) -> ArchiveKind? {
        matchedSuffix(for: url)?.kind
    }

    static func isRecognizedArchive(_ url: URL) -> Bool {
        matchedSuffix(for: url) != nil
    }


    static func themeName(forArchive url: URL) -> String {
        guard let match = matchedSuffix(for: url) else {
            return url.deletingPathExtension().lastPathComponent
        }
        return String(url.lastPathComponent.dropLast(match.suffix.count))
    }
}
