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

    public func expandedMessage(message: String, body: String, style: LevelStyle?, columns: Int, maxLines: Int) -> ExpandedMessageItem {
        let text = Self.expandedText(message: message, body: body)
        let lineCount = LogTextMetrics.wrappedLineCount(text.string, columns: columns, maxLines: .max)
        guard lineCount > maxLines else {
            return ExpandedMessageItem(
                text: expandedStyled(text.string, messageLength: text.messageLength, style: style),
                lineRanges: LogTextMetrics.wrappedLineRanges(ofDrawableText: text.string, columns: columns, maxLines: maxLines)
            )
        }
        let ranges = LogTextMetrics.wrappedLineRanges(ofDrawableText: text.string, columns: columns, maxLines: maxLines - 1)
        let shownEnd = String.Index(utf16Offset: ranges.last.map(NSMaxRange) ?? 0, in: text.string)
        let shown = expandedStyled(String(text.string[..<shownEnd]), messageLength: text.messageLength, style: style)
        let marker = Self.moreLinesText(lineCount - ranges.count)
        let markerRange = NSRange(location: shown.string.utf16.count + 1, length: marker.utf16.count)
        return ExpandedMessageItem(
            text: StyledText(string: shown.string + "\n" + marker, spans: shown.spans + [StyledText.Span(range: markerRange, style: .preview)]),
            lineRanges: ranges + [markerRange]
        )
    }

    public static func messageStyle(of record: LogRecord, in profile: LogProfile) -> LevelStyle? {
        guard let rule = record.level.flatMap(profile.rule(of:)), rule.colorsMessage else { return nil }
        return rule.style
    }
}

// MARK: - Private

private extension MessageTextBuilder {

    static func expandedText(message: String, body: String) -> (string: String, messageLength: Int) {
        let drawableMessage = LogTextMetrics.drawableText(message)
        guard body.isEmpty == false else { return (drawableMessage, drawableMessage.utf16.count) }
        return (LogTextMetrics.drawableText(message + "\n" + body), drawableMessage.utf16.count)
    }

    static func moreLinesText(_ count: Int) -> String {
        "… \(GroupedNumberText.text(count)) more lines. The inspector shows the whole entry."
    }

    func expandedStyled(_ string: String, messageLength: Int, style: LevelStyle?) -> StyledText {
        let length = string.utf16.count
        let messageEnd = min(messageLength, length)
        var spans = [StyledText.Span]()
        if messageEnd > 0 {
            spans.append(StyledText.Span(range: NSRange(location: 0, length: messageEnd), style: .message(style)))
        }
        if length > messageEnd {
            spans.append(StyledText.Span(range: NSRange(location: messageEnd, length: length - messageEnd), style: .detail))
        }
        return styled(string, baseSpans: spans)
    }

    func styled(_ string: String, baseSpans: [StyledText.Span]) -> StyledText {
        let matches = HighlightRanges.ranges(of: highlight, in: string).map { range in
            StyledText.Span(range: range, style: .globalMatch)
        }
        return StyledText(string: string, spans: baseSpans + matches)
    }
}
