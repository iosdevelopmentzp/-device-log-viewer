import Foundation
import LogReaderCore

public struct FilterResult: Sendable, Equatable {

    public let visible: [Int]
    public let findMatches: [Int]

    public init(visible: [Int], findMatches: [Int]) {
        self.visible = visible
        self.findMatches = findMatches
    }

    public static func compute(_ request: FilterRequest) throws -> FilterResult {
        let visible = try LogFilterEngine.indices(in: request.content, range: request.range, filter: request.filter)
        guard request.findQuery != nil || request.findTerms.isEmpty == false else {
            return FilterResult(visible: visible, findMatches: [])
        }
        let matches = try LogFilterEngine.textMatches(
            in: request.content,
            candidates: visible,
            query: request.findQuery,
            terms: request.findTerms,
            isRegex: request.filter.isRegex,
            scope: request.filter.scope
        )
        return FilterResult(visible: visible, findMatches: matches)
    }
}
