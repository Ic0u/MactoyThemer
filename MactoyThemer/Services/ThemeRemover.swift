import Foundation

/// Deletes installed themes from a Ventoy volume and prunes the matching
/// entries out of `ventoy.json`. Like `ThemeInstaller`, this owns its own
/// threading and calls back on the main queue.
enum ThemeRemover {
    static func removeTheme(
        named name: String,
        from volume: VentoyVolume,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        perform(completion) {
            let folder = volume.themesDirectory.appendingPathComponent(name, isDirectory: true)
            try removeIfPresent(folder)

            guard let folderPath = ThemeFileScanner.relativePosixPath(of: folder, volumeRoot: volume.mountURL) else {
                return
            }
            try updateConfig(on: volume) { config in
                config.themeFiles = config.themeFiles.filter { !ThemeFileScanner.path($0, isWithin: folderPath) }
                config.fontFiles = config.fontFiles.filter { !ThemeFileScanner.path($0, isWithin: folderPath) }
                config.imageFiles = config.imageFiles.filter { !ThemeFileScanner.path($0, isWithin: folderPath) }

                // Reset to random only when the stored index now runs off the
                // end of the shrunk list. Deliberately a literal port of the
                // original's rule — it does not try to re-target the index
                // onto whichever theme shifted into that slot.
                if config.defaultFileIndex > config.themeFiles.count {
                    config.defaultFileIndex = 0
                }
            }
        }
    }

    static func removeAllThemes(
        from volume: VentoyVolume,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        perform(completion) {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: volume.themesDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []
            for item in contents where ThemeFileScanner.isDirectory(item) {
                try removeIfPresent(item)
            }

            try updateConfig(on: volume) { config in
                config.themeFiles = []
                config.fontFiles = []
                config.imageFiles = []
                config.defaultFileIndex = 0
            }
        }
    }

    // MARK: - Shared plumbing

    private static func perform(
        _ completion: @escaping (Result<Void, Error>) -> Void,
        work: @escaping () throws -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work() }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// No config file means there is nothing to prune — a drive can hold
    /// theme folders Ventoy was never told about.
    private static func updateConfig(on volume: VentoyVolume, _ edit: (ThemeConfig) -> Void) throws {
        guard FileManager.default.fileExists(atPath: volume.configFileURL.path) else { return }
        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        edit(config)
        try config.save(to: volume.configFileURL)
    }
}
