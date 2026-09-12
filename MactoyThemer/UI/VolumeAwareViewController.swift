import AppKit

/// Shared scaffolding for the app's programmatic (no xib) view controllers:
/// the injected `VolumeManager`, the `init(coder:)` stub AppKit demands, a
/// plain backing view, and the `.volumeManagerDidChange` subscription.
///
/// Subclasses supply layout and their reaction to state changes; none of them
/// re-implement the observer lifecycle or hold their own copy of the
/// selected volume.
class VolumeAwareViewController: NSViewController {
    let volumeManager: VolumeManager

    init(volumeManager: VolumeManager) {
        self.volumeManager = volumeManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 340))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        applyLocalizedStrings()
        NotificationCenter.default.addObserver(
            self, selector: #selector(volumeStateDidChange), name: .volumeManagerDidChange, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(languageDidChange), name: .appLanguageDidChange, object: nil
        )
        volumeStateDidChange()
    }

    /// Re-applies the fixed text this screen shows — labels, button titles,
    /// tooltips. Kept separate from `buildLayout` so it can run again whenever
    /// the language changes.
    func applyLocalizedStrings() {}

    @objc private func languageDidChange() {
        applyLocalizedStrings()
        // State-derived text (status lines, popup contents) is produced here,
        // so it has to run again for the new language to reach those too.
        volumeStateDidChange()
    }

    /// Build the view hierarchy and constraints. Called once, before the
    /// first `volumeStateDidChange`.
    func buildLayout() {}

    /// Re-read whatever this controller shows from `volumeManager`. Called on
    /// load and on every change to the selection or config.
    @objc func volumeStateDidChange() {}
}
