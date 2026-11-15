import AppKit
import LogReaderKit
import SwiftUI

struct TextStyleSheet {

    let fontSize: Double
    let fontFamily: FontFamily

    var font: NSFont { LogFonts.text(size: fontSize, weight: .regular, family: fontFamily) }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: LogColors.primaryText]
    }

    static var linkAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: LogColors.link, .underlineStyle: NSUnderlineStyle.single.rawValue]
    }

    func attributes(for style: TextStyle) -> [NSAttributedString.Key: Any] {
        switch style {
        case .message(let style):
            [.foregroundColor: LevelColors.message(for: style)]
        case .preview:
            [.foregroundColor: LogColors.faintText]
        case .detail:
            [.foregroundColor: LogColors.secondaryText]
        case .title:
            [.font: LogFonts.text(size: fontSize + 1, weight: .semibold, family: fontFamily), .foregroundColor: LogColors.primaryText]
        case .fieldKey:
            [.font: LogFonts.text(size: fontSize, weight: .semibold, family: fontFamily), .foregroundColor: LogColors.secondaryText]
        case .fieldValue:
            [.foregroundColor: LogColors.primaryText]
        case .globalMatch:
            [.backgroundColor: LogColors.globalMatch, .foregroundColor: LogColors.matchText]
        case .localMatch:
            [.backgroundColor: LogColors.localMatch, .foregroundColor: LogColors.matchText]
        case .badge:
            [.font: LogFonts.text(size: max(fontSize - 2, 8), weight: .bold, family: fontFamily), .foregroundColor: LogColors.secondaryText]
        }
    }

    func swiftUIFont(for style: TextStyle) -> Font {
        Font(attributes(for: style)[.font] as? NSFont ?? font)
    }

    func color(for style: TextStyle) -> Color {
        Color(nsColor: attributes(for: style)[.foregroundColor] as? NSColor ?? LogColors.primaryText)
    }
}
