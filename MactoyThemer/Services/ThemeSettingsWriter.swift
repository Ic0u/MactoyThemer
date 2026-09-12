import Foundation

/// Writes the two Themes Settings values into `ventoy.json`. These are single
/// key edits on an already-loaded config, so unlike install and remove they
/// run synchronously on the caller's (main) thread.
enum ThemeSettingsWriter {
    /// `defaultFileIndex` is Ventoy's 1-based index into `theme.file`, with 0
    /// meaning "pick at random". The Settings popup lists "Random Theme" at
    /// row 0 and the themes in `theme.file` order after it, so the selected
    /// row index *is* the value Ventoy wants — no name lookup needed, and no
    /// ambiguity if two themes somehow share a display name.
    static func apply(
        defaultFileIndex: Int,
        gfxMode: String?,
        to config: ThemeConfig,
        savingTo url: URL
    ) throws {
        config.defaultFileIndex = max(0, min(defaultFileIndex, config.themeFiles.count))
        if let gfxMode, ThemeDefaults.gfxModes.contains(gfxMode) {
            config.gfxMode = gfxMode
        }
        try config.save(to: url)
    }
}
