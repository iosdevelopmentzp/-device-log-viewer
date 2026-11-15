import AppKit
import LogReaderKit

struct LogCellConfigurator {

    let sheet: TextStyleSheet

    private var expandedSheet: TextStyleSheet {
        TextStyleSheet(fontSize: sheet.fontSize, wrapsByCharacter: true, fontFamily: sheet.fontFamily)
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
        let badge = item.repeatCount == nil
            ? nil
            : NSAttributedString(string: item.repeatCountText, attributes: sheet.attributes(for: .badge))
        cell.setGroup(badge: badge, isExpanded: item.isGroupExpanded, isMember: item.isGroupMember)
        cell.onToggle = { [weak cell] in
            guard let cell else { return }
            onToggle(cell)
        }
    }

    func configureExpanded(_ cell: LogCellView, message: StyledText, maxLines: Int) {
        cell.label.maximumNumberOfLines = maxLines
        cell.setAttributedText(NSAttributedString(message, sheet: expandedSheet))
    }
}
