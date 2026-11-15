import AppKit

final class LogNSTableView: NSTableView {

    var onCopy: (() -> Void)?
    var onToggleInspector: (() -> Void)?
    var onToggleGroup: ((_ isExpanding: Bool) -> Bool)?

    private static let rightArrowKeyCode: UInt16 = 124
    private static let leftArrowKeyCode: UInt16 = 123

    override func keyDown(with event: NSEvent) {
        if let isExpanding = groupExpansion(for: event), onToggleGroup?(isExpanding) == true {
            return
        }
        guard event.charactersIgnoringModifiers == " ", event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
            super.keyDown(with: event)
            return
        }
        onToggleInspector?()
    }

    @objc func copy(_ sender: Any?) {
        onCopy?()
    }
}

// MARK: - Private

private extension LogNSTableView {

    func groupExpansion(for event: NSEvent) -> Bool? {
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return nil }
        switch event.keyCode {
        case Self.rightArrowKeyCode: return true
        case Self.leftArrowKeyCode: return false
        default: return nil
        }
    }
}

// MARK: - NSMenuItemValidation

extension LogNSTableView: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(copy(_:)) else { return true }
        return selectedRowIndexes.isEmpty == false
    }
}
