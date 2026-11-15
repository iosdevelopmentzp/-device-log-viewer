import AppKit

final class LogCellView: NSTableCellView {

    let label = NSTextField(labelWithString: "")
    private let expandedText: ExpandedTextView?
    var onToggle: (() -> Void)?
    var verticalInset: CGFloat = 3 {
        didSet { top?.constant = verticalInset }
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { applyStyle() }
    }

    private var plainColor: NSColor = LogColors.primaryText
    private var attributedText: NSAttributedString?
    private var badgeText: NSAttributedString?
    private var groupControls: (disclosure: NSButton, badge: NSTextField)?
    private var plainLeading: NSLayoutConstraint?
    private var groupLeading: NSLayoutConstraint?
    private var top: NSLayoutConstraint?

    private var content: NSView { expandedText ?? label }

    static let horizontalInset: CGFloat = 4
    static let memberIndent: CGFloat = 16
    private static let disclosureSpacing: CGFloat = 2
    private static let badgeSpacing: CGFloat = 4
    private static let disclosureWidth = makeDisclosure().intrinsicContentSize.width
    private static let badgeTemplate = makeBadge()

    init(identifier: NSUserInterfaceItemIdentifier, isMultiline: Bool, hasGroupControls: Bool) {
        expandedText = isMultiline ? ExpandedTextView() : nil
        super.init(frame: .zero)
        self.identifier = identifier
        let content = content
        content.translatesAutoresizingMaskIntoConstraints = false
        content.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(content)
        if let expandedText {
            expandedText.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        } else {
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.truncatesLastVisibleLine = true
            textField = label
        }
        let plainLeading = content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset)
        self.plainLeading = plainLeading
        let top = content.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset)
        self.top = top
        NSLayoutConstraint.activate([
            plainLeading,
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset),
            top
        ])
        if hasGroupControls {
            installGroupControls()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setText(_ text: String, color: NSColor) {
        attributedText = nil
        plainColor = color
        label.stringValue = text
        applyStyle()
    }

    func setAttributedText(_ text: NSAttributedString) {
        attributedText = text
        applyStyle()
    }

    func setExpandedText(_ text: NSAttributedString, lineRanges: [NSRange], lineHeight: CGFloat, font: NSFont) {
        expandedText?.setLines(lineRanges, lineHeight: lineHeight, font: font)
        setAttributedText(text)
    }

    func setGroup(badge: NSAttributedString?, isExpanded: Bool, isMember: Bool) {
        guard let groupControls, let plainLeading, let groupLeading else { return }
        let isGroup = badge != nil
        badgeText = badge
        groupControls.disclosure.isHidden = isGroup == false
        groupControls.badge.isHidden = isGroup == false
        groupControls.disclosure.state = isExpanded ? .on : .off
        plainLeading.constant = Self.horizontalInset + (isMember ? Self.memberIndent : 0)
        plainLeading.isActive = isGroup == false
        groupLeading.isActive = isGroup
        applyStyle()
    }

    static func groupInset(badge: NSAttributedString) -> CGFloat {
        badgeTemplate.attributedStringValue = badge
        return disclosureWidth + disclosureSpacing + badgeTemplate.intrinsicContentSize.width + badgeSpacing
    }
}

// MARK: - Private

private extension LogCellView {

    static func makeDisclosure() -> NSButton {
        let disclosure = NSButton(title: "", target: nil, action: nil)
        disclosure.bezelStyle = .disclosure
        disclosure.setButtonType(.pushOnPushOff)
        disclosure.controlSize = .small
        return disclosure
    }

    static func makeBadge() -> NSTextField {
        let badge = NSTextField(labelWithString: "")
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        return badge
    }

    func installGroupControls() {
        let disclosure = Self.makeDisclosure()
        disclosure.target = self
        disclosure.action = #selector(toggleGroup)
        disclosure.translatesAutoresizingMaskIntoConstraints = false
        disclosure.isHidden = true
        let badge = Self.makeBadge()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isHidden = true
        addSubview(disclosure)
        addSubview(badge)
        groupControls = (disclosure, badge)
        groupLeading = content.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Self.badgeSpacing)
        NSLayoutConstraint.activate([
            disclosure.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset),
            disclosure.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badge.leadingAnchor.constraint(equalTo: disclosure.trailingAnchor, constant: Self.disclosureSpacing),
            badge.firstBaselineAnchor.constraint(equalTo: content.firstBaselineAnchor)
        ])
    }

    @objc func toggleGroup() {
        onToggle?()
    }

    func applyStyle() {
        let isEmphasized = backgroundStyle == .emphasized
        if let badgeText, let badge = groupControls?.badge {
            badge.attributedStringValue = isEmphasized ? Self.emphasized(badgeText) : badgeText
        }
        guard let attributedText else {
            label.textColor = isEmphasized ? .alternateSelectedControlTextColor : plainColor
            return
        }
        let text = isEmphasized ? Self.emphasized(attributedText) : attributedText
        if let expandedText {
            expandedText.text = text
        } else {
            label.attributedStringValue = text
        }
    }

    static func emphasized(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.foregroundColor, value: NSColor.alternateSelectedControlTextColor, range: fullRange)
        result.enumerateAttribute(.backgroundColor, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            result.addAttribute(.foregroundColor, value: LogColors.matchText, range: range)
        }
        return result
    }
}
