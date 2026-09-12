import Foundation

/// Locations Ventoy itself defines, relative to the root of the mounted
/// Ventoy data volume.
enum VentoyPaths {
    static let configFile = "ventoy/ventoy.json"
    static let themesDirectory = "ventoy/theme"
    static let themeDescriptorName = "theme.txt"
    static let fontExtension = "pf2"
}

/// Values Ventoy expects inside the `theme` object of `ventoy.json`.
enum ThemeDefaults {
    /// GRUB resolutions Ventoy accepts for `gfxmode`.
    static let gfxModes = [
        "max", "3840x2160", "2560x1440", "1920x1080", "1680x1050", "1600x900",
        "1440x900", "1280x1024", "1280x960", "1024x768", "800x600"
    ]
    static let gfxMode = "max"
    static let displayMode = "GUI"
    static let serialParam = "--unit=0 --speed=9600"

    /// `default_file == 0` tells Ventoy to pick a theme at random each boot,
    /// so the picker shows this label in that slot.
    static let randomThemeLabel = "Random Theme"
}
