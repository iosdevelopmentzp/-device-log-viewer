import Foundation
import LogReaderCore

public struct MessageTextBuilder: Sendable {

    private let highlight: [TextQuery]

    private static let previewSeparator = "   "

    public init(highlight: [TextQuery]) {
        self.highlight = highlight
    }

    public func rowMessage(for record: LogRecord, profile: LogProfile) -> StyledText {
        let messageLength = record.message.utf16.count
        var spans = [StyledText.Span]()
        if messageLength > 0 {
            spans.append(StyledText.Span(range: NSRange(location: 0, length: messageLength), style: .message(Self.messageStyle(of: record, in: profile))))
        }
        guard record.detailPreview.isEmpty == false else {
            return styled(record.message, baseSpans: spans)
        }
        let preview = Self.previewSeparator + record.detailPreview
        spans.append(StyledText.Span(range: NSRange(location: messageLength, length: preview.utf16.count), style: .preview))
        return styled(record.message + preview, baseSpans: spans)
    }

    public func expandedMessage(text: String, messageLength: Int, style: LevelStyle?) -> StyledText {
        let messageEnd = text.index(text.startIndex, offsetBy: min(messageLength, text.count))
        let messageRange = NSRange(text.startIndex..<messageEnd, in: text)
        let detailRange = NSRange(messageEnd..<text.endIndex, in: text)
        var spans = [StyledText.Span]()
        if messageRange.length > 0 {
            spans.append(StyledText.Span(range: messageRange, style: .message(style)))
        }
        if detailRange.length > 0 {
            spans.append(StyledText.Span(range: detailRange, style: .detail))
        }
        return styled(text, baseSpans: spans)
    }

    public static func messageStyle(of record: LogRecord, in profile: LogProfile) -> LevelStyle? {
        guard let rule = record.level.flatMap(profile.rule(of:)), rule.colorsMessage else { return nil }
        return rule.style
    }
}

// MARK: - Private

private extension MessageTextBuilder {

    func styled(_ string: String, baseSpans: [StyledText.Span]) -> StyledText {
        let matches = HighlightRanges.ranges(of: highlight, in: string).map { range in
            StyledText.Span(range: range, style: .globalMatch)
        }
        return StyledText(string: string, spans: baseSpans + matches)
    }
}
