import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct MessageTextBuilderTests {

    @Test func rowMessageHasMessageSpanThenPreviewSpan() {
        let builder = MessageTextBuilder(highlight: [])

        let text = builder.rowMessage(for: Self.record(message: "Payment failed", preview: "reason: timeout", level: "error"), profile: LogFixtures.profile)

        #expect(text.string == "Payment failed   reason: timeout")
        #expect(text.spans == [
            StyledText.Span(range: NSRange(location: 0, length: 14), style: .message(.red)),
            StyledText.Span(range: NSRange(location: 14, length: 18), style: .preview)
        ])
    }

    @Test func rowMessageWithoutPreviewHasOnlyTheMessageSpan() {
        let builder = MessageTextBuilder(highlight: [])

        let text = builder.rowMessage(for: Self.record(message: "Line one ⏎ Line two", preview: "", level: nil), profile: LogFixtures.profile)

        #expect(text.string == "Line one ⏎ Line two")
        #expect(text.spans == [StyledText.Span(range: NSRange(location: 0, length: 19), style: .message(nil))])
    }

    @Test func matchSpansComeAfterBaseSpans() {
        let builder = MessageTextBuilder(highlight: [TextQuery("TIME")].compactMap { $0 })

        let text = builder.rowMessage(for: Self.record(message: "Timeout", preview: "after time", level: "info"), profile: LogFixtures.profile)

        #expect(text.spans.map(\.style) == [.message(nil), .preview, .globalMatch, .globalMatch])
        #expect(text.spans[2].range == NSRange(location: 0, length: 4))
        #expect(text.spans[3].range == NSRange(location: 16, length: 4))
    }

    @Test func regexHighlightMarksEveryMatch() throws {
        let builder = MessageTextBuilder(highlight: [try TextQuery.regex("user/\\d+")])

        let text = builder.rowMessage(for: Self.record(message: "User/1 and user/22", preview: "", level: nil), profile: LogFixtures.profile)

        #expect(text.spans.map(\.style) == [.message(nil), .globalMatch, .globalMatch])
        #expect(text.spans[1].range == NSRange(location: 0, length: 6))
        #expect(text.spans[2].range == NSRange(location: 11, length: 7))
    }

    @Test func expandedMessageSplitsMessageAndDetail() {
        let builder = MessageTextBuilder(highlight: [TextQuery("value")].compactMap { $0 })

        let item = builder.expandedMessage(message: "Hello", body: "key: value", style: .orange, columns: 80, maxLines: 10)

        #expect(item.text.string == "Hello\nkey: value")
        #expect(item.text.spans == [
            StyledText.Span(range: NSRange(location: 0, length: 5), style: .message(.orange)),
            StyledText.Span(range: NSRange(location: 5, length: 11), style: .detail),
            StyledText.Span(range: NSRange(location: 11, length: 5), style: .globalMatch)
        ])
        #expect(item.lineRanges == [NSRange(location: 0, length: 5), NSRange(location: 6, length: 10)])
    }

    @Test func expandedMessageWithoutBodyHasNoDetailSpan() {
        let builder = MessageTextBuilder(highlight: [])

        let item = builder.expandedMessage(message: "Hello", body: "", style: nil, columns: 80, maxLines: 10)

        #expect(item.text.spans == [StyledText.Span(range: NSRange(location: 0, length: 5), style: .message(nil))])
        #expect(item.lineRanges == [NSRange(location: 0, length: 5)])
    }

    @Test func expandedMessageReplacesTabsAndCarriageReturns() {
        let builder = MessageTextBuilder(highlight: [])

        let item = builder.expandedMessage(message: "a\tb", body: "c\r\nd\re", style: nil, columns: 80, maxLines: 10)

        #expect(item.text.string == "a    b\nc\nd\ne")
        #expect(item.lineRanges.count == 4)
        #expect(LogTextMetrics.wrappedLineCount("a\tb\nc\r\nd\re", columns: 80, maxLines: 10) == 4)
        #expect(LogTextMetrics.wrappedLineCount("a\tb", columns: 2, maxLines: 10) == 3)
    }

    @Test func expandedMessageCutsAtTheLineLimit() {
        let builder = MessageTextBuilder(highlight: [TextQuery("lines")].compactMap { $0 })

        let item = builder.expandedMessage(message: "abcdefghij", body: "", style: nil, columns: 2, maxLines: 3)

        #expect(item.text.string == "abcd\n… 3 more lines. The inspector shows the whole entry.")
        #expect(item.lineRanges == [NSRange(location: 0, length: 2), NSRange(location: 2, length: 2), NSRange(location: 5, length: 52)])
        #expect(item.text.spans == [
            StyledText.Span(range: NSRange(location: 0, length: 4), style: .message(nil)),
            StyledText.Span(range: NSRange(location: 5, length: 52), style: .preview)
        ])
    }

    @Test func messageStyleComesFromLevelsThatColorTheMessage() {
        let profile = LogFixtures.profile

        #expect(MessageTextBuilder.messageStyle(of: Self.record(message: "", preview: "", level: "error"), in: profile) == .red)
        #expect(MessageTextBuilder.messageStyle(of: Self.record(message: "", preview: "", level: "fault"), in: profile) == .purple)
        #expect(MessageTextBuilder.messageStyle(of: Self.record(message: "", preview: "", level: "warning"), in: profile) == nil)
        #expect(MessageTextBuilder.messageStyle(of: Self.record(message: "", preview: "", level: nil), in: profile) == nil)
    }

    private static func record(message: String, preview: String, level: String?) -> LogRecord {
        LogRecord(
            offset: 0,
            chunk: 0,
            start: 0,
            length: 0,
            metadataRange: 0..<0,
            level: level.flatMap(LogFixtures.profile.level(id:)),
            timestamp: nil,
            message: message,
            detailPreview: preview,
            attributes: [],
            isStructured: true
        )
    }

    @Test func severalQueriesMergeOverlappingRanges() {
        let queries = [TextQuery("payment"), TextQuery("ment fail"), TextQuery("timeout")].compactMap { $0 }
        let builder = MessageTextBuilder(highlight: queries)

        let text = builder.rowMessage(for: Self.record(message: "Payment failed: timeout", preview: "", level: nil), profile: LogFixtures.profile)

        #expect(text.spans.map(\.style) == [.message(nil), .globalMatch, .globalMatch])
        #expect(text.spans[1].range == NSRange(location: 0, length: 12))
        #expect(text.spans[2].range == NSRange(location: 16, length: 7))
    }
}
