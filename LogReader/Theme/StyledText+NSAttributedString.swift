import AppKit
import LogReaderKit

extension NSAttributedString {

    convenience init(_ text: StyledText, sheet: TextStyleSheet) {
        let result = NSMutableAttributedString(string: text.string, attributes: sheet.baseAttributes)
        for span in text.spans where NSMaxRange(span.range) <= result.length {
            result.addAttributes(sheet.attributes(for: span.style), range: span.range)
        }
        self.init(attributedString: result)
    }
}
