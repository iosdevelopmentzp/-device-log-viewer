import AppKit

final class LogRowView: NSTableRowView {

    var isAlternate = false {
        didSet {
            guard isAlternate != oldValue else { return }
            needsDisplay = true
        }
    }

    var tint: NSColor? {
        didSet {
            guard tint != oldValue else { return }
            needsDisplay = true
        }
    }

    var isBookmarked = false {
        didSet {
            guard isBookmarked != oldValue else { return }
            needsDisplay = true
        }
    }

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("LogRowView")

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.reuseIdentifier
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func drawBackground(in dirtyRect: NSRect) {
        (isAlternate ? LogColors.alternateRow : LogColors.background).setFill()
        bounds.fill()
        if let tint {
            tint.setFill()
            bounds.fill()
        }
        guard isBookmarked else { return }
        NSColor.controlAccentColor.setFill()
        NSRect(x: 0, y: 0, width: 3, height: bounds.height).fill()
    }
}
