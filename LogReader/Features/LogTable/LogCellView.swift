import AppKit

final class LogCellView: NSTableCellView {

    let label = NSTextField(labelWithString: "")
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

    static let horizontalInset: CGFloat = 4
    static let memberIndent: CGFloat = 16
    private static let badgeSpacing: CGFloat = 4

    init(identifier: NSUserInterfaceItemIdentifier, isMultiline: Bool, hasGroupControls: Bool) {
        super.init(frame: .zero)
        self.identifier = identifier
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if isMultiline {
            label.lineBreakMode = .byCharWrapping
            label.maximumNumberOfLines = 0
            label.cell?.wraps = true
            label.cell?.truncatesLastVisibleLine = true
        } else {
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.cell?.truncatesLastVisibleLine = true
        }
        addSubview(label)
        textField = label
        let plainLeading = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset)
        self.plainLeading = plainLeading
        let top = label.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset)
        self.top = top
        NSLayoutConstraint.activate([
            plainLeading,
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset),
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
}

// MARK: - Private

private extension LogCellView {

    func installGroupControls() {
        let disclosure = NSButton(title: "", target: self, action: #selector(toggleGroup))
        disclosure.bezelStyle = .disclosure
        disclosure.setButtonType(.pushOnPushOff)
        disclosure.controlSize = .small
        disclosure.translatesAutoresizingMaskIntoConstraints = false
        disclosure.isHidden = true
        let badge = NSTextField(labelWithString: "")
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.isHidden = true
        addSubview(disclosure)
        addSubview(badge)
        groupControls = (disclosure, badge)
        groupLeading = label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Self.badgeSpacing)
        NSLayoutConstraint.activate([
            disclosure.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset),
            disclosure.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badge.leadingAnchor.constraint(equalTo: disclosure.trailingAnchor, constant: 2),
            badge.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor)
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
        label.attributedStringValue = isEmphasized ? Self.emphasized(attributedText) : attributedText
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
