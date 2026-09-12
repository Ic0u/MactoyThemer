import Foundation

/// Installs theme sources onto a Ventoy volume: unpack or copy each into
/// `ventoy/theme/<name>/`, then merge the discovered `theme.txt` and `.pf2`
/// paths into `ventoy/ventoy.json`.
///
/// Owns its own threading. The work runs on a background queue and every
/// callback is delivered on the main queue, so callers can touch AppKit
/// directly — and can't accidentally invoke this from the main thread and
/// deadlock against the modal overwrite prompt.
enum ThemeInstaller {
    static func install(
        sources: [ThemeSource],
        into volume: VentoyVolume,
        progress: @escaping (InstallProgress) -> Void,
        confirmOverwrite: @escaping (String) -> Bool,
        completion: @escaping (Result<InstallSummary, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try run(
                    sources: sources,
                    volume: volume,
                    report: { update in DispatchQueue.main.async { progress(update) } },
                    askOverwrite: { name in DispatchQueue.main.sync { confirmOverwrite(name) } }
                )
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// Only ever called from the background queue `install` dispatches to:
    /// `askOverwrite` blocks on the main queue, so running this on main would
    /// deadlock.
    private static func run(
        sources: [ThemeSource],
        volume: VentoyVolume,
        report: (InstallProgress) -> Void,
        askOverwrite: (String) -> Bool
    ) throws -> InstallSummary {
        dispatchPrecondition(condition: .notOnQueue(.main))

        let fileManager = FileManager.default
        var themePaths = Set<String>()
        var fontPaths = Set<String>()
        var warnings: [String] = []
        var processed = 0
        var skipped = 0

        for (index, source) in sources.enumerated() {
            let name = source.themeName
            let startFraction = Double(index) / Double(sources.count)
            let destination = volume.themesDirectory.appendingPathComponent(name, isDirectory: true)

            if fileManager.fileExists(atPath: destination.path) {
                report(InstallProgress(message: "Confirming overwrite for \(name)…", fraction: startFraction))
                guard askOverwrite(name) else {
                    skipped += 1
                    report(InstallProgress(message: "Skipped existing theme: \(name)", fraction: startFraction))
                    continue
                }
                do {
                    try fileManager.removeItem(at: destination)
                } catch {
                    warnings.append("Could not replace existing theme '\(name)': \(error.localizedDescription)")
                    continue
                }
            }

            do {
                switch source {
                case .archive(let url):
                    report(InstallProgress(message: "Extracting \(name)…", fraction: startFraction))
                    try ArchiveExtractor.extract(url, to: destination)
                case .themeFolder(let url):
                    report(InstallProgress(message: "Copying \(name)…", fraction: startFraction))
                    try fileManager.copyItem(at: url, to: destination)
                }
            } catch {
                warnings.append("Could not install '\(name)': \(error.localizedDescription)")
                continue
            }

            let assets = ThemeFileScanner.scanAssets(in: destination)
            if let descriptor = assets.themeDescriptor {
                insert(descriptor, of: volume, into: &themePaths)
            } else {
                // Ventoy needs a theme.txt to render anything, but recording
                // the folder still lets the entry round-trip through
                // ventoy.json instead of silently vanishing.
                warnings.append("No theme.txt found in '\(name)'; it may not display correctly.")
                insert(destination, of: volume, into: &themePaths)
            }
            for font in assets.fontFiles {
                insert(font, of: volume, into: &fontPaths)
            }

            processed += 1
            report(InstallProgress(
                message: "Installed \(name)",
                fraction: Double(index + 1) / Double(sources.count)
            ))
        }

        guard processed > 0 else {
            return InstallSummary(processedCount: 0, skippedCount: skipped, warnings: warnings)
        }

        report(InstallProgress(message: "Updating ventoy.json…", fraction: 1))
        // Re-read from disk rather than reusing the app's in-memory copy: this
        // run just changed the volume, and another tab may have written since.
        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        config.themeFiles = union(config.themeFiles, themePaths)
        config.fontFiles = union(config.fontFiles, fontPaths)
        try config.save(to: volume.configFileURL)

        return InstallSummary(processedCount: processed, skippedCount: skipped, warnings: warnings)
    }

    private static func insert(_ url: URL, of volume: VentoyVolume, into paths: inout Set<String>) {
        guard let path = ThemeFileScanner.relativePosixPath(of: url, volumeRoot: volume.mountURL) else { return }
        paths.insert(path)
    }

    /// Sorted for deterministic output; the order carries no meaning to
    /// Ventoy beyond `default_file`'s index into it.
    private static func union(_ existing: [String], _ added: Set<String>) -> [String] {
        Set(existing).union(added).sorted()
    }
}
