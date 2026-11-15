import Foundation
import LogReaderCore

public enum HighlightRanges {

    public static func ranges(of queries: [TextQuery], in string: String) -> [NSRange] {
        let sorted = queries
            .flatMap { $0.ranges(in: string) }
            .map { NSRange($0, in: string) }
            .sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        for range in sorted {
            guard let last = merged.last, range.location <= NSMaxRange(last) else {
                merged.append(range)
                continue
            }
            merged[merged.count - 1] = NSUnionRange(last, range)
        }
        return merged
    }
}
