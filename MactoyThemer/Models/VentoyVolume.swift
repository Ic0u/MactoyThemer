import Foundation

/// A mounted volume the app can write themes to. `isAutoDetected` marks the
/// ones whose name matches what mactoy/Ventoy format the data partition as;
/// everything else mounted is still offered, since users rename drives.
struct VentoyVolume: Equatable, Hashable {
    let name: String
    let mountURL: URL
    let isAutoDetected: Bool

    var themesDirectory: URL {
        mountURL.appendingPathComponent(VentoyPaths.themesDirectory, isDirectory: true)
    }

    var configFileURL: URL {
        mountURL.appendingPathComponent(VentoyPaths.configFile, isDirectory: false)
    }
}
