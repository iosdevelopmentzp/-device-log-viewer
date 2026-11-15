import AppKit

enum LogColors {

    static let background = dynamic(light: NSColor(srgbRed: 0.945, green: 0.941, blue: 0.929, alpha: 1), dark: .controlBackgroundColor)
    static let alternateRow = dynamic(light: NSColor(srgbRed: 0.918, green: 0.914, blue: 0.898, alpha: 1), dark: .alternatingContentBackgroundColors.last ?? .controlBackgroundColor)
    static let primaryText = dynamic(light: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 1), dark: .labelColor)
    static let secondaryText = dynamic(light: NSColor(srgbRed: 0.36, green: 0.36, blue: 0.38, alpha: 1), dark: .secondaryLabelColor)
    static let faintText = dynamic(light: NSColor(srgbRed: 0.5, green: 0.5, blue: 0.52, alpha: 1), dark: .tertiaryLabelColor)
    static let tag = dynamic(light: NSColor(srgbRed: 0.33, green: 0.3, blue: 0.7, alpha: 1), dark: .systemIndigo)
    static let globalMatch = NSColor.systemYellow
    static let localMatch = NSColor.systemOrange
    static let matchText = NSColor.black
    static let link = NSColor.linkColor
    static let findRowTint = NSColor.systemYellow.withAlphaComponent(0.14)
    static let chipBackground = NSColor.secondaryLabelColor.withAlphaComponent(0.12)
    static let chipExclusion = NSColor.systemOrange
    static let warningText = NSColor.systemOrange
    static let clearedBannerBackground = NSColor.systemOrange.withAlphaComponent(0.12)

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}
