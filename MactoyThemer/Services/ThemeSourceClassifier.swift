import Foundation

/// Turns a raw URL — dropped on the list or picked in the open panel — into
/// the flat list of installable sources it represents.
enum ThemeSourceClassifier {
    /// Resolution order, matching how the Windows original reads a dropped path:
    ///
    /// 1. A file → an archive, if the extension is recognized (else ignored).
    /// 2. A folder with archives directly inside → each archive is a source.
    /// 3. Else a folder whose direct subfolders hold themes → each is a source.
    /// 4. Else a folder that holds a theme itself → the folder is one source.
    /// 5. Otherwise → nothing installable here.
    ///
    /// Note steps 2–4 look only one level down; a dropped folder is either a
    /// batch of themes or a single theme, never a tree to search recursively.
    static func classify(_ url: URL) -> [ThemeSource] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }

        guard isDirectory.boolValue else {
            return ArchiveKind.isRecognizedArchive(url) ? [.archive(url)] : []
        }

        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        let archives = children.filter { !ThemeFileScanner.isDirectory($0) && ArchiveKind.isRecognizedArchive($0) }
        if !archives.isEmpty {
            return archives.sorted { $0.path < $1.path }.map { .archive($0) }
        }

        let themeFolders = children.filter {
            ThemeFileScanner.isDirectory($0) && ThemeFileScanner.containsThemeDescriptor(in: $0)
        }
        if !themeFolders.isEmpty {
            return themeFolders.sorted { $0.path < $1.path }.map { .themeFolder($0) }
        }

        return ThemeFileScanner.containsThemeDescriptor(in: url) ? [.themeFolder(url)] : []
    }

    /// Classifies several URLs at once, dropping anything already staged so
    /// re-dropping a folder can't queue the same theme twice.
    static func classify(_ urls: [URL], excluding staged: Set<URL>) -> [ThemeSource] {
        var seen = staged
        var results: [ThemeSource] = []
        for url in urls {
            for source in classify(url) where seen.insert(source.url).inserted {
                results.append(source)
            }
        }
        return results
    }
}
