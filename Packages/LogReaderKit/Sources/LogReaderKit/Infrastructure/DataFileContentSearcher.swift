import Foundation
import LogReaderCore

public final class DataFileContentSearcher: Sendable {

    public init() {}
}

// MARK: - FileContentSearcher

extension DataFileContentSearcher: FileContentSearcher {

    public func countMatches(of query: TextQuery, in url: URL, sizeLimit: Int) throws -> FileSearchResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .skipped }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size <= sizeLimit else { return .skipped }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return .count(data.withUnsafeBytes { query.countMatches(in: $0) })
    }
}
