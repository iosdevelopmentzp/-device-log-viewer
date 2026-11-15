import Foundation
import LogReaderCore

public protocol FileContentSearcher: AnyObject, Sendable {
    func countMatches(of query: TextQuery, in url: URL, sizeLimit: Int) throws -> FileSearchResult
}
