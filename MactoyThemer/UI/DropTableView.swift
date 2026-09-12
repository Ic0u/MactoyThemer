import AppKit

/// A plain (non-reordering) list that accepts files and folders dropped from
/// Finder. Implemented as `NSDraggingDestination` overrides rather than the
/// datasource's drop hooks, which exist for intra-table row reordering.
final class DropTableView: NSTableView {
    var onDrop: (([URL]) -> Void)?
    var onDeleteKey: (() -> Void)?

    /// Cleared while an install is running. `isEnabled` alone doesn't stop
    /// AppKit from routing a drag here.
    var acceptsDrops = true

    private enum KeyCode {
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = dropOperation(for: sender)
        if operation == .copy {
            backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.12)
        }
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        backgroundColor = .textBackgroundColor
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        backgroundColor = .textBackgroundColor
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOperation(for: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        backgroundColor = .textBackgroundColor
        guard acceptsDrops,
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty
        else { return false }

        onDrop?(urls)
        return true
    }

    private func dropOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops, sender.draggingPasteboard.types?.contains(.fileURL) == true else { return [] }
        return .copy
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == KeyCode.delete || event.keyCode == KeyCode.forwardDelete else {
            super.keyDown(with: event)
            return
        }
        onDeleteKey?()
    }
}
