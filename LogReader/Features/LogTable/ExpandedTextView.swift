import AppKit

final class ExpandedTextView: NSView {

    var text = NSAttributedString() {
        didSet { needsDisplay = true }
    }

    private var lineRanges: [NSRange] = []
    private var lineHeight: CGFloat = 16
    private var baselineOffset: CGFloat = 12

    override var isFlipped: Bool { true }

    override var firstBaselineOffsetFromTop: CGFloat { baselineOffset }

    init() {
        super.init(frame: .zero)
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setLines(_ lineRanges: [NSRange], lineHeight: CGFloat, font: NSFont) {
        self.lineRanges = lineRanges
        self.lineHeight = lineHeight
        baselineOffset = ceil(font.ascender)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard lineRanges.isEmpty == false, lineHeight > 0 else { return }
        let first = max(0, Int(dirtyRect.minY / lineHeight))
        let last = min(lineRanges.count - 1, Int(dirtyRect.maxY / lineHeight))
        guard first <= last else { return }
        let length = text.length
        for index in first...last where NSMaxRange(lineRanges[index]) <= length {
            text.attributedSubstring(from: lineRanges[index]).draw(at: NSPoint(x: 0, y: CGFloat(index) * lineHeight))
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - NSAccessibility

extension ExpandedTextView {

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .staticText
    }

    override func accessibilityValue() -> Any? {
        text.string
    }
}
