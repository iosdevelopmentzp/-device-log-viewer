import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct EntryTextLayoutBuilderTests {

    private let details = LogEntryDetails.parse(
        "Request failed ERR [default] [Api:1] 2026-10-07 22:18:54.000\n  status: 500\n  reason: failed again",
        record: LogFixtures.record(message: "Request failed", level: "error", tags: [], category: "default", source: "Api:1"),
        profile: LogFixtures.profile
    )

    @Test func buildsTitleFieldKeyAndValueSpans() {
        let layout = EntryTextLayoutBuilder(globalQueries: [], localQuery: nil).layout(for: details)

        #expect(layout.text.string == "Request failed\n\nstatus\n500\n\nreason\nfailed again")
        #expect(layout.text.spans == [
            StyledText.Span(range: NSRange(location: 0, length: 14), style: .title),
            StyledText.Span(range: NSRange(location: 16, length: 7), style: .fieldKey),
            StyledText.Span(range: NSRange(location: 23, length: 3), style: .fieldValue),
            StyledText.Span(range: NSRange(location: 28, length: 7), style: .fieldKey),
            StyledText.Span(range: NSRange(location: 35, length: 12), style: .fieldValue)
        ])
        #expect(layout.localMatches.isEmpty)
    }

    @Test func globalMatchesComeBeforeLocalMatches() {
        let layout = EntryTextLayoutBuilder(globalQueries: [TextQuery("failed")].compactMap { $0 }, localQuery: TextQuery("FAIL")).layout(for: details)

        #expect(layout.text.spans.map(\.style) == [
            .title, .fieldKey, .fieldValue, .fieldKey, .fieldValue,
            .globalMatch, .globalMatch,
            .localMatch, .localMatch
        ])
        #expect(layout.localMatches == [NSRange(location: 8, length: 4), NSRange(location: 35, length: 4)])
    }

    @Test func findsHTTPLinksWithTheirRanges() throws {
        let layout = EntryTextLayoutBuilder(globalQueries: [], localQuery: nil)
            .layout(for: details(message: "See https://example.com/a?b=1 and http://example.org/x now"))

        #expect(layout.links == [
            EntryTextLink(range: NSRange(location: 4, length: 25), url: try #require(URL(string: "https://example.com/a?b=1"))),
            EntryTextLink(range: NSRange(location: 34, length: 20), url: try #require(URL(string: "http://example.org/x")))
        ])
    }

    @Test func ignoresMailAddresses() {
        let layout = EntryTextLayoutBuilder(globalQueries: [], localQuery: nil)
            .layout(for: details(message: "Write to support@example.com or mailto:help@example.com"))

        #expect(layout.links.isEmpty)
    }

    @Test func bareDomainWithoutSchemeBecomesAnHTTPLink() throws {
        let layout = EntryTextLayoutBuilder(globalQueries: [], localQuery: nil)
            .layout(for: details(message: "Open www.example.com today"))

        #expect(layout.links == [
            EntryTextLink(range: NSRange(location: 5, length: 15), url: try #require(URL(string: "http://www.example.com")))
        ])
    }
}

// MARK: - Private

private extension EntryTextLayoutBuilderTests {

    func details(message: String) -> LogEntryDetails {
        LogEntryDetails.parse(
            message + " INF [default] [Api:1] 2026-10-07 22:18:54.000",
            record: LogFixtures.record(message: message, level: "info", tags: [], category: "default", source: "Api:1"),
            profile: LogFixtures.profile
        )
    }

    @Test func globalMatchesComeFromEveryQuery() {
        let queries = [TextQuery("failed"), TextQuery("reason")].compactMap { $0 }
        let layout = EntryTextLayoutBuilder(globalQueries: queries, localQuery: nil).layout(for: details)

        let globalRanges = layout.text.spans.filter { $0.style == .globalMatch }.map(\.range)
        #expect(globalRanges.count == 3)
        #expect(globalRanges == globalRanges.sorted { $0.location < $1.location })
    }
}
