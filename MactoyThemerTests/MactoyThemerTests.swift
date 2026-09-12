import AppKit
import XCTest
@testable import MactoyThemer

/// Tests for the pure logic and the filesystem layer, run against temporary
/// directories standing in for a mounted Ventoy volume — so the whole
/// install/remove/config stack is covered without a USB stick plugged in.
final class MactoyThemerTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MactoyThemerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    // MARK: - Helpers

    /// Builds a fake mounted volume with the given themes already installed.
    private func makeVolume(named name: String = "Ventoy", themes: [String] = []) throws -> VentoyVolume {
        let root = sandbox.appendingPathComponent(name, isDirectory: true)
        let volume = VentoyVolume(name: name, mountURL: root, isAutoDetected: true)
        try FileManager.default.createDirectory(at: volume.themesDirectory, withIntermediateDirectories: true)
        for theme in themes {
            try makeThemeFolder(named: theme, in: volume.themesDirectory)
        }
        return volume
    }

    @discardableResult
    private func makeThemeFolder(named name: String, in parent: URL, fontCount: Int = 0) throws -> URL {
        let folder = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# theme".write(to: folder.appendingPathComponent("theme.txt"), atomically: true, encoding: .utf8)
        guard fontCount > 0 else { return folder }

        let fonts = folder.appendingPathComponent("fonts", isDirectory: true)
        try FileManager.default.createDirectory(at: fonts, withIntermediateDirectories: true)
        for index in 0..<fontCount {
            try Data().write(to: fonts.appendingPathComponent("font\(index).pf2"))
        }
        return folder
    }

    private func writeConfig(_ object: [String: Any], to volume: VentoyVolume) throws {
        try FileManager.default.createDirectory(
            at: volume.configFileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: object)
        try data.write(to: volume.configFileURL)
    }

    private func readConfig(of volume: VentoyVolume) throws -> [String: Any] {
        let data = try Data(contentsOf: volume.configFileURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Path translation

    func testRelativePosixPathStripsTheVolumeRoot() {
        let root = URL(fileURLWithPath: "/Volumes/Ventoy", isDirectory: true)
        let file = URL(fileURLWithPath: "/Volumes/Ventoy/ventoy/theme/Slate/theme.txt")

        XCTAssertEqual(
            ThemeFileScanner.relativePosixPath(of: file, volumeRoot: root),
            "/ventoy/theme/Slate/theme.txt"
        )
    }

    /// With two sticks mounted, macOS names the second "Ventoy 1". A raw
    /// string prefix test would treat its files as living on "Ventoy".
    func testRelativePosixPathRejectsASiblingVolumeWithASharedNamePrefix() {
        let root = URL(fileURLWithPath: "/Volumes/Ventoy", isDirectory: true)
        let file = URL(fileURLWithPath: "/Volumes/Ventoy 1/ventoy/theme/Slate/theme.txt")

        XCTAssertNil(ThemeFileScanner.relativePosixPath(of: file, volumeRoot: root))
    }

    func testPathContainmentMatchesWholeComponentsCaseInsensitively() {
        // Ventoy volumes are exFAT/FAT32, so casing must not decide identity.
        XCTAssertTrue(ThemeFileScanner.path("/ventoy/theme/Slate/theme.txt", isWithin: "/ventoy/theme/slate"))
        XCTAssertTrue(ThemeFileScanner.path("/ventoy/theme/Slate", isWithin: "/ventoy/theme/Slate"))
        // "SlateDark" must not be swept up when deleting "Slate".
        XCTAssertFalse(ThemeFileScanner.path("/ventoy/theme/SlateDark/theme.txt", isWithin: "/ventoy/theme/Slate"))
    }

    // MARK: - App delegate

    /// AppKit finds this by selector, so the Swift method existing isn't
    /// enough — it has to be exposed to the ObjC runtime. Guards against the
    /// `@objc` being dropped, which silently brings the secure-coding warning
    /// back with no compile error.
    func testDelegateExposesSecureRestorableStateToTheObjCRuntime() throws {
        guard #available(macOS 12.0, *) else {
            throw XCTSkip("applicationSupportsSecureRestorableState is macOS 12+")
        }
        let delegate = AppDelegate()
        let selector = NSSelectorFromString("applicationSupportsSecureRestorableState:")

        XCTAssertTrue(delegate.responds(to: selector), "AppKit cannot see the method")
        XCTAssertTrue(delegate.applicationSupportsSecureRestorableState(NSApplication.shared))
    }

    // MARK: - Volume selection

    private func mounted(
        _ name: String,
        root: Bool = false,
        readOnly: Bool = false,
        removable: Bool = true,
        disk: String? = "disk2"
    ) -> MountedVolumeInfo {
        MountedVolumeInfo(
            name: name,
            mountURL: URL(fileURLWithPath: "/Volumes/\(name)", isDirectory: true),
            isRootFileSystem: root,
            isReadOnly: readOnly,
            isRemovable: removable,
            wholeDisk: disk
        )
    }

    /// The list used to show the startup disk and Ventoy's own EFI partition,
    /// neither of which is a place themes can go.
    func testTheBootVolumeAndVentoysEFIPartitionAreNeverOffered() {
        let picked = VolumeScanner.select(from: [
            mounted("Untitled", root: true, removable: false, disk: "disk1"),
            mounted("VTOYEFI"),
            mounted("Ventoy")
        ])
        XCTAssertEqual(picked.map(\.name), ["Ventoy"])
    }

    /// Ventoy puts its data partition next to a VTOYEFI partition on the same
    /// physical disk, so a renamed drive is still recognisable.
    func testARenamedDataPartitionIsDetectedViaItsVTOYEFISibling() {
        let picked = VolumeScanner.select(from: [
            mounted("MyBootStick", disk: "disk2"),
            mounted("VTOYEFI", disk: "disk2")
        ])
        XCTAssertEqual(picked.map(\.name), ["MyBootStick"])
        XCTAssertEqual(picked.first?.isAutoDetected, true)
    }

    func testInternalAndReadOnlyVolumesAreNotOffered() {
        let picked = VolumeScanner.select(from: [
            mounted("Macintosh HD - Data", removable: false, disk: "disk3"),
            mounted("Installer", readOnly: true, disk: "disk4"),
            mounted("BackupSSD", disk: "disk5")
        ])
        // Only the writable removable drive survives, and it is flagged as
        // unconfirmed rather than presented as a Ventoy drive.
        XCTAssertEqual(picked.map(\.name), ["BackupSSD"])
        XCTAssertEqual(picked.first?.isAutoDetected, false)
    }

    func testDetectedDrivesAreListedAheadOfUnconfirmedOnes() {
        let picked = VolumeScanner.select(from: [
            mounted("Aaa Stick", disk: "disk5"),
            mounted("Ventoy", disk: "disk2")
        ])
        XCTAssertEqual(picked.map(\.name), ["Ventoy", "Aaa Stick"])
    }

    func testWholeDiskNameParsing() {
        XCTAssertEqual(VolumeScanner.wholeDiskName(fromDevicePath: "/dev/disk2s1"), "disk2")
        XCTAssertEqual(VolumeScanner.wholeDiskName(fromDevicePath: "/dev/disk12s3s1"), "disk12")
        XCTAssertNil(VolumeScanner.wholeDiskName(fromDevicePath: "map -hosts"))
        XCTAssertNil(VolumeScanner.wholeDiskName(fromDevicePath: "//server/share"))
    }

    // MARK: - Archive naming

    func testThemeNameStripsCompoundArchiveExtensions() {
        let cases = [
            "Slate.zip": "Slate",
            "Slate.tar.gz": "Slate",
            "Slate.tar.zst": "Slate",
            "Slate.tgz": "Slate",
            "My.Theme.v2.tar.bz2": "My.Theme.v2"
        ]
        for (fileName, expected) in cases {
            let url = URL(fileURLWithPath: "/tmp/\(fileName)")
            XCTAssertEqual(ArchiveKind.themeName(forArchive: url), expected, "for \(fileName)")
        }
    }

    // MARK: - ThemeConfig

    func testSavePreservesUnrelatedKeysAtEveryLevel() throws {
        let volume = try makeVolume()
        try writeConfig([
            "control": [["VTOY_DEFAULT_MENU_MODE": "1"]],
            "menu_alias": ["something"],
            "theme": [
                "file": ["/ventoy/theme/Slate/theme.txt"],
                "ventoy_left": "5%"
            ]
        ], to: volume)

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        config.gfxMode = "1920x1080"
        try config.save(to: volume.configFileURL)

        let saved = try readConfig(of: volume)
        XCTAssertNotNil(saved["control"], "unrelated top-level key was dropped")
        XCTAssertEqual(saved["menu_alias"] as? [String], ["something"])

        let theme = try XCTUnwrap(saved["theme"] as? [String: Any])
        XCTAssertEqual(theme["ventoy_left"] as? String, "5%", "unrelated theme key was dropped")
        XCTAssertEqual(theme["gfxmode"] as? String, "1920x1080")
        XCTAssertEqual(theme["file"] as? [String], ["/ventoy/theme/Slate/theme.txt"])
    }

    func testSaveFillsInVentoyDefaultsWithoutOverwritingExistingValues() throws {
        let volume = try makeVolume()
        try writeConfig(["theme": ["gfxmode": "800x600"]], to: volume)

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        try config.save(to: volume.configFileURL)

        let theme = try XCTUnwrap(try readConfig(of: volume)["theme"] as? [String: Any])
        XCTAssertEqual(theme["gfxmode"] as? String, "800x600", "existing value was overwritten by the default")
        XCTAssertEqual(theme["display_mode"] as? String, ThemeDefaults.displayMode)
        XCTAssertEqual(theme["serial_param"] as? String, ThemeDefaults.serialParam)
        XCTAssertEqual(theme["default_file"] as? Int, 0)
        XCTAssertEqual(theme["fonts"] as? [String], [])
    }

    func testLoadingAMissingConfigYieldsAnEmptyOneRatherThanThrowing() throws {
        let volume = try makeVolume()
        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, [])
        XCTAssertEqual(config.defaultFileIndex, 0)
    }

    /// A drive with no themes is the ordinary first-run state, and it used to
    /// crash the Settings tab by building the range `1...0`.
    func testDefaultThemeRowIsRandomWhenNoThemesAreInstalled() {
        XCTAssertEqual(ThemeConfig().defaultThemeRow, 0)
        XCTAssertEqual(ThemeConfig(root: ["theme": ["default_file": 3]]).defaultThemeRow, 0)
    }

    func testDefaultThemeRowTracksAValidStoredIndex() {
        let config = ThemeConfig(root: ["theme": [
            "file": ["/ventoy/theme/Slate/theme.txt", "/ventoy/theme/Nord/theme.txt"],
            "default_file": 2
        ]])
        XCTAssertEqual(config.defaultThemeRow, 2)
    }

    func testInstalledThemeNamesComeFromTheContainingFolder() {
        let config = ThemeConfig(root: ["theme": ["file": [
            "/ventoy/theme/Slate/theme.txt",
            "/ventoy/theme/Nord/theme.txt"
        ]]])
        XCTAssertEqual(config.installedThemeNames, ["Slate", "Nord"])
    }

    // MARK: - Source classification

    func testASingleThemeFolderClassifiesAsOneSource() throws {
        let folder = try makeThemeFolder(named: "Slate", in: sandbox)
        XCTAssertEqual(ThemeSourceClassifier.classify(folder), [.themeFolder(folder)])
    }

    func testAFolderOfThemeFoldersExpandsIntoOneSourceEach() throws {
        let batch = sandbox.appendingPathComponent("Batch", isDirectory: true)
        try FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
        try makeThemeFolder(named: "Slate", in: batch)
        try makeThemeFolder(named: "Nord", in: batch)

        let sources = ThemeSourceClassifier.classify(batch)
        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources.map(\.themeName).sorted(), ["Nord", "Slate"])
    }

    func testAFolderWithNoThemeYieldsNothing() throws {
        let empty = sandbox.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try "hello".write(to: empty.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ThemeSourceClassifier.classify(empty), [])
    }

    func testAlreadyStagedSourcesAreNotQueuedTwice() throws {
        let folder = try makeThemeFolder(named: "Slate", in: sandbox)
        let staged: Set<URL> = [folder]
        XCTAssertEqual(ThemeSourceClassifier.classify([folder], excluding: staged), [])
    }

    // MARK: - Install

    func testInstallingAFolderCopiesItAndRecordsItsThemeAndFonts() throws {
        let volume = try makeVolume()
        let source = try makeThemeFolder(named: "Slate", in: sandbox, fontCount: 2)

        let summary = try installSynchronously([.themeFolder(source)], into: volume)
        XCTAssertEqual(summary.processedCount, 1)
        XCTAssertEqual(summary.warnings, [])

        let installed = volume.themesDirectory.appendingPathComponent("Slate/theme.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.path))

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, ["/ventoy/theme/Slate/theme.txt"])
        XCTAssertEqual(config.fontFiles, [
            "/ventoy/theme/Slate/fonts/font0.pf2",
            "/ventoy/theme/Slate/fonts/font1.pf2"
        ])
    }

    func testInstallingMergesIntoExistingEntriesInsteadOfReplacingThem() throws {
        let volume = try makeVolume()
        try writeConfig(["theme": ["file": ["/ventoy/theme/Nord/theme.txt"], "default_file": 1]], to: volume)
        let source = try makeThemeFolder(named: "Slate", in: sandbox)

        _ = try installSynchronously([.themeFolder(source)], into: volume)

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, [
            "/ventoy/theme/Nord/theme.txt",
            "/ventoy/theme/Slate/theme.txt"
        ])
        XCTAssertEqual(config.defaultFileIndex, 1, "an unrelated default selection was disturbed")
    }

    func testDecliningAnOverwriteLeavesTheInstalledThemeUntouched() throws {
        let volume = try makeVolume(themes: ["Slate"])
        let marker = volume.themesDirectory.appendingPathComponent("Slate/marker.txt")
        try "original".write(to: marker, atomically: true, encoding: .utf8)
        let source = try makeThemeFolder(named: "Slate", in: sandbox)

        let summary = try installSynchronously([.themeFolder(source)], into: volume, confirmOverwrite: false)

        XCTAssertEqual(summary.processedCount, 0)
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "original")
    }

    func testInstallingAZipArchiveExtractsIt() throws {
        let volume = try makeVolume()
        let folder = try makeThemeFolder(named: "Slate", in: sandbox)
        let archive = sandbox.appendingPathComponent("Slate.zip")

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-ck", "--norsrc", folder.path, archive.path]
        try zip.run()
        zip.waitUntilExit()
        try XCTSkipUnless(zip.terminationStatus == 0, "could not build the test archive")

        let summary = try installSynchronously([.archive(archive)], into: volume)
        XCTAssertEqual(summary.processedCount, 1)

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, ["/ventoy/theme/Slate/theme.txt"])
    }

    // MARK: - Remove

    func testRemovingAThemeDeletesItAndPrunesOnlyItsEntries() throws {
        let volume = try makeVolume(themes: ["Slate", "SlateDark"])
        try writeConfig(["theme": [
            "file": ["/ventoy/theme/Slate/theme.txt", "/ventoy/theme/SlateDark/theme.txt"],
            "fonts": ["/ventoy/theme/Slate/fonts/a.pf2", "/ventoy/theme/SlateDark/fonts/b.pf2"],
            "default_file": 2
        ]], to: volume)

        try removeSynchronously(themeNamed: "Slate", from: volume)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: volume.themesDirectory.appendingPathComponent("Slate").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: volume.themesDirectory.appendingPathComponent("SlateDark").path
        ), "a theme sharing a name prefix was deleted too")

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, ["/ventoy/theme/SlateDark/theme.txt"])
        XCTAssertEqual(config.fontFiles, ["/ventoy/theme/SlateDark/fonts/b.pf2"])
    }

    func testRemovingResetsADefaultIndexThatNowRunsPastTheList() throws {
        let volume = try makeVolume(themes: ["Slate"])
        try writeConfig(["theme": [
            "file": ["/ventoy/theme/Slate/theme.txt"],
            "default_file": 1
        ]], to: volume)

        try removeSynchronously(themeNamed: "Slate", from: volume)

        let config = try ThemeConfig.loadIfPresent(at: volume.configFileURL)
        XCTAssertEqual(config.themeFiles, [])
        XCTAssertEqual(config.defaultFileIndex, 0, "default_file still points at a theme that is gone")
    }

    // MARK: - Settings

    func testApplyingSettingsClampsTheDefaultIndexToTheInstalledThemes() throws {
        let volume = try makeVolume()
        let config = ThemeConfig(root: ["theme": ["file": ["/ventoy/theme/Slate/theme.txt"]]])

        try ThemeSettingsWriter.apply(defaultFileIndex: 7, gfxMode: "1920x1080", to: config, savingTo: volume.configFileURL)
        XCTAssertEqual(config.defaultFileIndex, 1)

        try ThemeSettingsWriter.apply(defaultFileIndex: -3, gfxMode: nil, to: config, savingTo: volume.configFileURL)
        XCTAssertEqual(config.defaultFileIndex, 0)
    }

    func testApplyingAnUnknownResolutionIsIgnored() throws {
        let volume = try makeVolume()
        let config = ThemeConfig()

        try ThemeSettingsWriter.apply(defaultFileIndex: 0, gfxMode: "9999x9999", to: config, savingTo: volume.configFileURL)
        XCTAssertEqual(config.gfxMode, ThemeDefaults.gfxMode)
    }

    // MARK: - Async bridges

    /// The install/remove services deliver callbacks on the main queue, so
    /// these drive the runloop until the work lands.
    private func installSynchronously(
        _ sources: [ThemeSource],
        into volume: VentoyVolume,
        confirmOverwrite: Bool = true
    ) throws -> InstallSummary {
        let finished = expectation(description: "install")
        var outcome: Result<InstallSummary, Error>?

        ThemeInstaller.install(
            sources: sources,
            into: volume,
            progress: { _ in },
            confirmOverwrite: { _ in confirmOverwrite },
            completion: { result in
                outcome = result
                finished.fulfill()
            }
        )

        wait(for: [finished], timeout: 30)
        return try XCTUnwrap(outcome).get()
    }

    private func removeSynchronously(themeNamed name: String, from volume: VentoyVolume) throws {
        let finished = expectation(description: "remove")
        var outcome: Result<Void, Error>?

        ThemeRemover.removeTheme(named: name, from: volume) { result in
            outcome = result
            finished.fulfill()
        }

        wait(for: [finished], timeout: 30)
        try XCTUnwrap(outcome).get()
    }
}
