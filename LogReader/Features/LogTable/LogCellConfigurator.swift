import AppKit
import LogReaderKit

struct LogCellConfigurator {

    let sheet: TextStyleSheet

    var expandedSheet: TextStyleSheet {
        TextStyleSheet(fontSize: sheet.fontSize, fontFamily: .monospaced)
    }

    func configure(_ cell: LogCellView, column: LogTableColumnItem, item: LogRowItem) {
        let label = cell.label
        label.font = sheet.font
        label.alignment = column.alignment
        label.toolTip = nil
        switch column.kind {
        case .number:
            cell.setText(item.numberText, color: LogColors.faintText)
        case .time:
            cell.setText(item.time, color: LogColors.secondaryText)
            label.toolTip = item.fullDate
        case .delta:
            cell.setText(item.delta, color: LogColors.faintText)
        case .level:
            cell.setText(item.levelCode, color: LevelColors.text(for: item.levelStyle))
        case .list:
            cell.setText(item.attribute(at: column.attributeIndex ?? -1), color: LogColors.tag)
        case .text:
            cell.setText(item.attribute(at: column.attributeIndex ?? -1), color: LogColors.secondaryText)
        case .message:
            cell.setAttributedText(NSAttributedString(item.message, sheet: sheet))
        }
    }

    func configureGroup(_ cell: LogCellView, item: LogRowItem, onToggle: @escaping (LogCellView) -> Void) {
        let badge = item.repeatCount == nil ? nil : badgeText(item.repeatCountText)
        cell.setGroup(badge: badge, isExpanded: item.isGroupExpanded, isMember: item.isGroupMember)
        cell.onToggle = { [weak cell] in
            guard let cell else { return }
            onToggle(cell)
        }
    }

    func configureExpanded(_ cell: LogCellView, item: ExpandedMessageItem, lineHeight: CGFloat) {
        let sheet = expandedSheet
        cell.setExpandedText(NSAttributedString(item.text, sheet: sheet), lineRanges: item.lineRanges, lineHeight: lineHeight, font: sheet.font)
    }

    func groupInset(for indent: GroupIndent) -> CGFloat {
        switch indent {
        case .none: 0
        case .member: LogCellView.memberIndent
        case .group(let badge): LogCellView.groupInset(badge: badgeText(badge))
        }
    }
}

// MARK: - Private

private extension LogCellConfigurator {

    func badgeText(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: sheet.attributes(for: .badge))
    }
}
