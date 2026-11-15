import Foundation
import LogReaderCore

public struct EntryTextLayoutBuilder: Sendable {

    private let globalQueries: [TextQuery]
    private let localQuery: TextQuery?

    private static let fieldSeparator = "\n\n"
    private static let linkSchemes: Set<String> = ["http", "https", "file"]
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    public init(globalQueries: [TextQuery], localQuery: TextQuery?) {
        self.globalQueries = globalQueries
        self.localQuery = localQuery
    }

    public func layout(for details: LogEntryDetails) -> EntryTextLayout {
        var string = ""
        var spans = [StyledText.Span]()
        append(details.message, style: .title, to: &string, spans: &spans)
        for field in details.fields {
            string += Self.fieldSeparator
            if field.key.isEmpty == false {
                append(field.key + "\n", style: .fieldKey, to: &string, spans: &spans)
            }
            append(field.prettyValue ?? field.value, style: .fieldValue, to: &string, spans: &spans)
        }
        let globalMatches = HighlightRanges.ranges(of: globalQueries, in: string)
        let localMatches = matches(of: localQuery, in: string)
        spans += globalMatches.map { StyledText.Span(range: $0, style: .globalMatch) }
        spans += localMatches.map { StyledText.Span(range: $0, style: .localMatch) }
        return EntryTextLayout(
            text: StyledText(string: string, spans: spans),
            localMatches: localMatches,
            links: links(in: string)
        )
    }
}

// MARK: - Private

private extension EntryTextLayoutBuilder {

    func append(_ text: String, style: TextStyle, to string: inout String, spans: inout [StyledText.Span]) {
        let location = string.utf16.count
        string += text
        let length = text.utf16.count
        guard length > 0 else { return }
        spans.append(StyledText.Span(range: NSRange(location: location, length: length), style: style))
    }

    func matches(of query: TextQuery?, in string: String) -> [NSRange] {
        guard let query else { return [] }
        return query.ranges(in: string).map { NSRange($0, in: string) }
    }

    func links(in string: String) -> [EntryTextLink] {
        guard let detector = Self.linkDetector else { return [] }
        let range = NSRange(location: 0, length: string.utf16.count)
        return detector.matches(in: string, options: [], range: range).compactMap { result in
            guard let url = result.url, let scheme = url.scheme?.lowercased(), Self.linkSchemes.contains(scheme) else { return nil }
            return EntryTextLink(range: result.range, url: url)
        }
    }
}
