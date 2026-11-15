import AppKit
import LogReaderKit

enum LogFonts {

    static func text(size: Double, weight: NSFont.Weight, family: FontFamily) -> NSFont {
        switch family {
        case .monospaced: .monospacedSystemFont(ofSize: size, weight: weight)
        case .system: .systemFont(ofSize: size, weight: weight)
        }
    }
}
