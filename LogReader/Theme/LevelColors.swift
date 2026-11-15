import AppKit
import LogReaderCore
import LogReaderKit

enum LevelColors {

    static func text(for style: LevelStyle?) -> NSColor {
        guard let style else { return LogColors.faintText }
        return palette(style)
    }

    static func message(for style: LevelStyle?) -> NSColor {
        guard let style else { return LogColors.primaryText }
        return palette(style)
    }

    static func rowTint(for item: LogRowItem) -> NSColor? {
        guard item.highlightsRow else { return nil }
        return text(for: item.levelStyle).withAlphaComponent(0.08)
    }
}

// MARK: - Private

private extension LevelColors {

    static func palette(_ style: LevelStyle) -> NSColor {
        switch style {
        case .primary: LogColors.primaryText
        case .secondary: LogColors.secondaryText
        case .blue: .systemBlue
        case .teal: .systemTeal
        case .green: .systemGreen
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .red: .systemRed
        case .purple: .systemPurple
        }
    }
}
