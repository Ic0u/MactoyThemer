import Foundation

/// One mounted volume as observed before deciding whether to offer it as a
/// theme target. Split out from the enumeration so the filtering rules below
/// are a pure function that can be tested without mounting anything.
struct MountedVolumeInfo: Equatable {
    let name: String
    let mountURL: URL
    let isRootFileSystem: Bool
    let isReadOnly: Bool
    /// Removable or ejectable — a USB stick, card, or external drive.
    let isRemovable: Bool
    /// The whole disk this partition lives on, e.g. "disk2", or nil if it
    /// couldn't be determined.
    let wholeDisk: String?

    /// Ventoy's own 32 MiB EFI partition. It sits next to the data partition
    /// on every Ventoy drive and holds the bootloader — never themes.
    var isVentoyEFIPartition: Bool {
        name.caseInsensitiveCompare("VTOYEFI") == .orderedSame
    }

    /// The label mactoy and Ventoy give the data partition, with macOS
    /// suffixing duplicates as "Ventoy 1", "Ventoy 2" for multiple sticks.
    var hasVentoyName: Bool {
        name == "Ventoy" || name.hasPrefix("Ventoy")
    }
}

/// Finds the volumes worth offering as theme targets.
enum VolumeScanner {
    static func scanMountedVolumes() -> [VentoyVolume] {
        select(from: probeMountedVolumes())
    }

    /// Decides what to list, and what to leave out.
    ///
    /// A volume is treated as a Ventoy drive when it carries the Ventoy name
    /// **or** shares a physical disk with a mounted `VTOYEFI` partition —
    /// the second test is what still recognises a data partition the user
    /// renamed, since Ventoy's own layout puts the two side by side.
    ///
    /// Deliberately never listed: the boot volume, read-only mounts,
    /// `VTOYEFI` itself, and internal fixed disks. Those aren't places
    /// themes belong, and listing them just invites picking the wrong one.
    /// "Choose…" remains the escape hatch for anything unusual.
    static func select(from mounted: [MountedVolumeInfo]) -> [VentoyVolume] {
        let ventoyDisks = Set(mounted.compactMap { $0.isVentoyEFIPartition ? $0.wholeDisk : nil })

        var detected: [VentoyVolume] = []
        var removableFallback: [VentoyVolume] = []

        for info in mounted where !info.isRootFileSystem && !info.isReadOnly && !info.isVentoyEFIPartition {
            let isVentoy = info.hasVentoyName || info.wholeDisk.map(ventoyDisks.contains) == true
            let volume = VentoyVolume(name: info.name, mountURL: info.mountURL, isAutoDetected: isVentoy)

            if isVentoy {
                detected.append(volume)
            } else if info.isRemovable {
                // A plain USB stick. Offered but flagged, in case it holds a
                // Ventoy install whose EFI partition macOS didn't mount.
                removableFallback.append(volume)
            }
        }

        let byName: (VentoyVolume, VentoyVolume) -> Bool = { $0.name < $1.name }
        return detected.sorted(by: byName) + removableFallback.sorted(by: byName)
    }

    // MARK: - Enumeration

    private static let resourceKeys: [URLResourceKey] = [
        .volumeNameKey, .volumeIsRootFileSystemKey, .volumeIsReadOnlyKey,
        .volumeIsRemovableKey, .volumeIsEjectableKey
    ]

    /// Uses `mountedVolumeURLs` rather than listing `/Volumes`: that folder
    /// also holds a symlink to the boot volume, which showed up as a
    /// bogus extra entry named after whatever the startup disk is called.
    private static func probeMountedVolumes() -> [MountedVolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: resourceKeys, options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)) else { return nil }
            return MountedVolumeInfo(
                name: values.volumeName ?? url.lastPathComponent,
                mountURL: url,
                isRootFileSystem: values.volumeIsRootFileSystem ?? false,
                isReadOnly: values.volumeIsReadOnly ?? false,
                isRemovable: (values.volumeIsRemovable ?? false) || (values.volumeIsEjectable ?? false),
                wholeDisk: wholeDisk(forVolumeAt: url)
            )
        }
    }

    /// The BSD whole-disk name behind a mount point, via `statfs` —
    /// no subprocess, unlike shelling out to `diskutil`.
    private static func wholeDisk(forVolumeAt url: URL) -> String? {
        var info = statfs()
        guard statfs(url.path, &info) == 0 else { return nil }

        let device = withUnsafeBytes(of: &info.f_mntfromname) { raw -> String in
            guard let base = raw.baseAddress else { return "" }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
        return wholeDiskName(fromDevicePath: device)
    }

    /// "/dev/disk2s1" → "disk2". Returns nil for anything that isn't a
    /// numbered BSD disk (network mounts, synthesized containers, …).
    static func wholeDiskName(fromDevicePath devicePath: String) -> String? {
        let device = (devicePath as NSString).lastPathComponent
        guard device.hasPrefix("disk") else { return nil }

        let digits = device.dropFirst("disk".count).prefix(while: { $0.isNumber })
        return digits.isEmpty ? nil : "disk\(digits)"
    }
}
