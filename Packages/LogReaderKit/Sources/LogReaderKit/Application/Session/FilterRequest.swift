import Foundation
import LogReaderCore

public struct FilterRequest: Sendable {

    public let content: LogContent
    public let range: Range<Int>
    public let filter: LogFilter
    public let findQuery: TextQuery?
    public let findTerms: [SearchTerm]

    public init(content: LogContent, range: Range<Int>, filter: LogFilter, findQuery: TextQuery?, findTerms: [SearchTerm]) {
        self.content = content
        self.range = range
        self.filter = filter
        self.findQuery = findQuery
        self.findTerms = findTerms
    }
}
